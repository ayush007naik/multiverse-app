"""Product image lookup service.

Given a product's details (name, brand, variant, barcode) this service finds a
real photograph of *that* item on the internet, verifies the image by
downloading and re-encoding it, and re-hosts it in Supabase Storage so the
vendor dashboard can reference a stable URL of its own.

    GET  /health                     liveness + which providers are live
    POST /search                     ranked candidates for a product
    POST /resolve                    best match, verified and hosted
    POST /host                       host one specific image URL

The vendor dashboard calls ``/search`` from the "Find Image from Internet"
button (so the vendor picks from a grid) and ``/resolve`` during an Excel/CSV
import (so every row is filled without human involvement).
"""

import asyncio
import time
from contextlib import asynccontextmanager
from typing import Dict, List, Optional

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from . import cache, imaging, providers, scoring, storage
from .config import Config
from .models import ImageCandidate, ProductQuery, ResolveRequest, SearchResponse

_semaphore = asyncio.Semaphore(Config.MAX_CONCURRENT_HTTP)
_client: Optional[httpx.AsyncClient] = None

# Below this best score the query set clearly missed, so a shorter query is
# worth the extra provider quota. Both fallback passes share the bar, and each
# one only runs if the tier before it also came up short.
RELAX_TRIGGER_SCORE = 0.40


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _client
    _client = httpx.AsyncClient(
        timeout=httpx.Timeout(Config.HTTP_TIMEOUT),
        follow_redirects=True,
        headers={"User-Agent": Config.USER_AGENT, "Accept": "*/*"},
        limits=httpx.Limits(
            max_connections=Config.MAX_CONCURRENT_HTTP,
            max_keepalive_connections=4,
        ),
    )
    cache.purge_expired(Config.CACHE_TTL_SECONDS)
    yield
    if _client is not None:
        await _client.aclose()
        _client = None


app = FastAPI(
    title="Multiverse Product Image Search",
    version="1.0.0",
    description="Finds and hosts an exact product photo from the internet.",
    lifespan=lifespan,
)

# The vendor dashboard is a Flutter web app served from a different origin.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


def client() -> httpx.AsyncClient:
    if _client is None:  # pragma: no cover - only before startup completes
        raise HTTPException(status_code=503, detail="client not ready")
    return _client


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

async def require_vendor(
    authorization: Optional[str] = Header(default=None),
) -> Dict[str, object]:
    """Accepts a Firebase Auth ID token, as used elsewhere in this project.

    Verification is off by default so the service can be run locally without
    Firebase; set REQUIRE_AUTH=true in production. A caller must be
    identifiable, so an unknown bearer token is rejected even when auth is
    disabled — that keeps the door from standing wide open by accident.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        if Config.REQUIRE_AUTH:
            raise HTTPException(status_code=401, detail="missing bearer token")
        return {"uid": "anonymous"}

    token = authorization.split(" ", 1)[1].strip()
    if not token:
        if Config.REQUIRE_AUTH:
            raise HTTPException(status_code=401, detail="empty bearer token")
        return {"uid": "anonymous"}

    if not Config.REQUIRE_AUTH:
        # Cheap sanity check: a Firebase ID token is a JWT with three parts.
        if token.count(".") != 2:
            raise HTTPException(status_code=401, detail="malformed bearer token")
        return {"uid": "firebase"}

    try:
        response = await client().get(
            "https://identitytoolkit.googleapis.com/v1/accounts:lookup",
            params={"key": _firebase_api_key()},
            headers={"Authorization": f"Bearer {token}"},
        )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail=f"auth check failed: {exc}") from exc

    if response.status_code >= 400 or not response.json().get("users"):
        raise HTTPException(status_code=401, detail="invalid or expired token")
    user = response.json()["users"][0]
    return {"uid": user.get("localId"), "email": user.get("email")}


def _firebase_api_key() -> str:
    import os

    key = os.environ.get("FIREBASE_API_KEY", "")
    if not key:
        raise HTTPException(
            status_code=500,
            detail="FIREBASE_API_KEY is required when REQUIRE_AUTH=true",
        )
    return key


# ---------------------------------------------------------------------------
# Search pipeline
# ---------------------------------------------------------------------------

def _product_cache_key(product: ProductQuery) -> str:
    parts = [
        product.name.lower(),
        product.brand.lower(),
        product.variant.lower(),
        product.category.lower(),
        product.barcode,
    ]
    return cache.make_key("resolve", "|".join(parts))


def _candidate_cache_key(url: str) -> str:
    return cache.make_key("host", url)


async def _rank(product: ProductQuery, max_queries: int = 3) -> tuple:
    """Ranks candidates over up to three query tiers.

    The tiers run in order and each one only runs when everything before it
    left nothing above ``RELAX_TRIGGER_SCORE``, so the extra provider quota is
    spent on the rows that actually need it:

    1. ``branded``  -- the sheet's own words, brand included.
    2. ``relaxed``  -- brand plus the head noun, for long padded names.
    3. ``generic``  -- the product with the brand removed.

    Tier 3 is what a branded row was missing. A brand is only in a free photo
    library if somebody happened to upload that brand, so "JSW Steel TMT Bar"
    returns nothing at any score -- there is no file on Wikimedia carrying the
    word "JSW" -- and the row stayed blank. Tier 3 asks for a *steel TMT bar*
    instead, which the library can answer.

    A generic hit is scored against the brand-free product, so ``brand_match``
    is vacuously true for it and the guard in ``best_match`` does not apply.
    ``matched_by`` is deliberately left as scoring set it: unlike tier 2 there
    is no brand to honour, so "exact" still means an exact name match and the
    vendor grid keeps its usual signal.
    """
    raw, status = await providers.search_all(
        client(), product, max_queries=max_queries, tier="branded"
    )
    ranked = scoring.rank(raw, product)
    asked = providers.asked_queries(product, max_queries)

    best_so_far = max((c.score for c in ranked), default=0.0)
    if best_so_far < RELAX_TRIGGER_SCORE:
        relaxed = providers.relaxed_product(product)
        if _query_text(relaxed) != _query_text(product):
            extra, _ = await providers.search_all(
                client(), relaxed, max_queries=2, tier="relaxed"
            )
            asked |= providers.asked_queries(relaxed, 2)
            if extra:
                # Scored against the shortened target: "Colgate Toothpaste" is
                # a fair question when the sheet said "Colgate Strong Teeth
                # Toothpaste 150g", and a wrong answer still cannot be
                # auto-attached because best_match demands a brand match from
                # anything tagged "relaxed".
                relaxed_ranked = scoring.rank(extra, relaxed)
                for candidate in relaxed_ranked:
                    candidate.matched_by = "relaxed"
                already = {c.full_url for c in ranked}
                ranked = sorted(
                    ranked + [c for c in relaxed_ranked if c.full_url not in already],
                    key=lambda c: c.score,
                    reverse=True,
                )
                status["relaxed"] = {
                    "ok": True,
                    "count": len(relaxed_ranked),
                    "query": _query_text(relaxed),
                }
            # Re-read from the merged list: a relaxed hit can be the one that
            # settles the row, and the third pass must not run over it.
            best_so_far = max((c.score for c in ranked), default=0.0)

    if best_so_far < RELAX_TRIGGER_SCORE:
        generic = providers.generic_product(product)
        # The comparison is against the *generic* tier's queries. Checking the
        # original product here would compare the first pass against itself,
        # find nothing new, and skip the third pass for every row.
        if providers.asks_something_new(generic, 2, asked):
            extra, _ = await providers.search_all(
                client(), generic, max_queries=2, tier="generic"
            )
            if extra:
                generic_ranked = scoring.rank(extra, generic)
                # Scored against the brand-free product, so brand_match is
                # vacuous here. Put back the evidence the sheet actually has:
                # whether the picture names the brand it was looking for.
                scoring.apply_brand_evidence(generic_ranked, product)
                already = {c.full_url for c in ranked}
                ranked = sorted(
                    ranked + [c for c in generic_ranked if c.full_url not in already],
                    key=lambda c: c.score,
                    reverse=True,
                )
                status["generic"] = {
                    "ok": True,
                    "count": len(generic_ranked),
                    "query": _query_text(generic),
                }

    return ranked[: Config.MAX_CANDIDATES], status


def _query_text(product: ProductQuery) -> str:
    return f"{product.brand}|{product.name}|{product.variant}".strip().lower()


async def _host_candidate(
    candidate: ImageCandidate, folder: Optional[str] = None
) -> Optional[imaging.ProcessedImage]:
    """Downloads, validates, de-duplicates and uploads one candidate.

    Returns the processed image so the caller can read the true dimensions.
    """

    async def run() -> Optional[imaging.ProcessedImage]:
        async with _semaphore:
            return await imaging.download_and_process(client(), candidate.full_url)

    try:
        processed = await run()
    except (httpx.HTTPError, asyncio.TimeoutError, OSError, ValueError):
        return None
    if processed is None:
        return None
    if not storage.is_configured():
        return processed
    try:
        candidate.hosted_url = await storage.upload(
            client(), storage.object_path(processed.content_hash, folder), processed.jpeg
        )
    except (storage.StorageError, httpx.HTTPError):
        # The candidate is still usable via its provider URL.
        candidate.hosted_url = None
    return processed


async def _host_top(
    candidates: List[ImageCandidate], count: int, folder: Optional[str] = None
) -> List[ImageCandidate]:
    """Hosts the top [count] candidates concurrently, skipping duplicates.

    Cached uploads are resolved without a network round trip, which is what
    makes re-importing the same catalogue cheap.
    """
    if count <= 0:
        return []
    targets = candidates[:count]
    seen_hashes: set = set()

    async def handle(candidate: ImageCandidate) -> ImageCandidate:
        key = _candidate_cache_key(candidate.full_url)
        cached = cache.get_json(key, Config.CACHE_TTL_SECONDS)
        if cached:
            candidate.hosted_url = cached.get("hosted_url")
            candidate.width = cached.get("width") or candidate.width
            candidate.height = cached.get("height") or candidate.height
            return candidate

        processed = await _host_candidate(candidate, folder)
        if processed is None:
            return candidate
        if processed.dhash in seen_hashes:
            return candidate
        seen_hashes.add(processed.dhash)
        candidate.width = processed.width
        candidate.height = processed.height
        if candidate.hosted_url:
            cache.set_json(
                key,
                {
                    "hosted_url": candidate.hosted_url,
                    "width": processed.width,
                    "height": processed.height,
                },
            )
        return candidate

    return list(await asyncio.gather(*(handle(c) for c in targets)))


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

class SearchRequest(BaseModel):
    product: ProductQuery
    limit: int = Field(12, ge=1, le=40)
    # Number of top results to download and host up front, so the best matches
    # are already ours when the vendor taps one.
    host_top: int = Field(4, ge=0, le=12)
    folder: Optional[str] = None
    max_queries: int = Field(3, ge=1, le=5)


class HostRequest(BaseModel):
    # The URL comes from a grid tile, so it is untrusted: rejecting a blank one
    # here turns what used to be a 500 from the HTTP stack into a clean 422.
    full_url: str = Field(..., min_length=1, description="http(s) image URL")
    folder: Optional[str] = None


@app.get("/health")
async def health() -> dict:
    return {
        "status": "ok",
        "providers": Config.summary(),
        "cache_path": Config.CACHE_PATH,
    }


@app.post("/search", response_model=SearchResponse)
async def search(
    request: SearchRequest, _user: dict = Depends(require_vendor)
) -> SearchResponse:
    started = time.monotonic()
    product = request.product.trimmed()
    if not product.name:
        raise HTTPException(status_code=400, detail="product.name is required")

    ranked, status = await _rank(product, max_queries=request.max_queries)
    ranked = ranked[: request.limit]

    # Only reach for the network when there is something worth hosting.
    host_count = min(request.host_top, len(ranked))
    if host_count and storage.is_configured():
        ranked = await _host_top(ranked, host_count, request.folder)

    best = scoring.best_match(ranked, Config.MIN_ACCEPT_SCORE)
    return SearchResponse(
        query=" ".join(filter(None, [product.brand, product.name, product.variant])),
        found=bool(ranked),
        candidates=ranked,
        best=best,
        provider_status=status,
        duration_ms=int((time.monotonic() - started) * 1000),
    )


@app.post("/resolve", response_model=SearchResponse)
async def resolve(
    request: ResolveRequest, _user: dict = Depends(require_vendor)
) -> SearchResponse:
    """Finds the single best photo, verifies it and hosts it.

    Used by the spreadsheet importer: it must not attach a photo it is not
    confident about, so a low-scoring search returns ``found: false`` and the
    product is simply saved without an image.
    """
    started = time.monotonic()
    product = request.product.trimmed()
    if not product.name:
        raise HTTPException(status_code=400, detail="product.name is required")

    status: Dict[str, dict] = {}

    cached = cache.get_json(_product_cache_key(product), Config.CACHE_TTL_SECONDS)
    # A remembered answer is usable even when it carries no hosted copy: with
    # storage unconfigured the provider URL is what the product gets, and
    # re-running the whole search for a product we already answered for is
    # what makes a second import of the same catalogue slow.
    if cached and (cached.get("hosted_url") or cached.get("source_url")):
        source_url = cached.get("source_url") or ""
        hosted = cached.get("hosted_url")
        return SearchResponse(
            query=cached.get("query", product.name),
            found=True,
            candidates=[],
            best=ImageCandidate(
                full_url=source_url,
                # Never null: an entry cached before storage was configured
                # has no hosted copy, and the dashboard still needs something
                # to put in the grid. The provider URL serves as the
                # thumbnail in that case.
                thumbnail_url=hosted or source_url,
                hosted_url=hosted,
                title=cached.get("title", product.name),
                source=cached.get("source", "cache"),
                source_page=cached.get("source_page"),
                license=cached.get("license"),
                attribution=cached.get("attribution"),
                requires_attribution=bool(cached.get("requires_attribution")),
                width=cached.get("width"),
                height=cached.get("height"),
                score=1.0,
                matched_by="cache",
            ),
            provider_status={"cache": {"ok": True, "count": 1}},
            duration_ms=int((time.monotonic() - started) * 1000),
        )

    ranked, status = await _rank(product)
    best = scoring.best_match(ranked, Config.MIN_ACCEPT_SCORE)
    if best is None:
        return SearchResponse(
            query=product.name,
            found=False,
            candidates=ranked[:10] if request.include_candidates else [],
            provider_status=status,
            duration_ms=int((time.monotonic() - started) * 1000),
        )

    verify = max(1, min(request.verify_candidates, len(ranked)))
    if storage.is_configured():
        verified = await _host_top(ranked, verify, request.folder)
        # _host_top returns the whole slice, reordered by score, with entries
        # whose download failed left untouched. Pick the strongest one that
        # survived.
        winner = next((c for c in verified[:verify] if c.hosted_url), None)
    else:
        # Without storage there is nothing to download *for*: the product is
        # saved with the provider URL either way. Downloading, re-encoding and
        # re-ranking three images per row would triple the cost of an import
        # and throw the bytes away.
        winner = None
    if winner is None:
        # Storage is unavailable or every download failed: fall back to the
        # provider URL so the product still gets a picture.
        winner = best

    cache.set_json(
        _product_cache_key(product),
        {
            "query": " ".join(filter(None, [product.brand, product.name, product.variant])),
            "hosted_url": winner.hosted_url,
            "source_url": winner.full_url,
            "title": winner.title,
            "source": winner.source,
            "source_page": winner.source_page,
            "license": winner.license,
            "attribution": winner.attribution,
            "requires_attribution": winner.requires_attribution,
            "width": winner.width,
            "height": winner.height,
        },
    )

    return SearchResponse(
        query=" ".join(filter(None, [product.brand, product.name, product.variant])),
        found=True,
        candidates=ranked if request.include_candidates else [],
        best=winner,
        provider_status=status,
        duration_ms=int((time.monotonic() - started) * 1000),
    )


@app.post("/host")
async def host_image(
    request: HostRequest, _user: dict = Depends(require_vendor)
) -> JSONResponse:
    """Re-hosts a single image URL, used when the vendor picks a lower-ranked
    result from the grid."""
    key = _candidate_cache_key(request.full_url)
    cached = cache.get_json(key, Config.CACHE_TTL_SECONDS)
    if cached and cached.get("hosted_url"):
        return JSONResponse({"hosted_url": cached["hosted_url"], "cached": True})

    candidate = ImageCandidate(
        full_url=request.full_url,
        thumbnail_url=request.full_url,
        source="grid",
    )
    processed = await _host_candidate(candidate, request.folder)
    if processed is None:
        raise HTTPException(status_code=422, detail="image could not be downloaded")

    payload = {
        "hosted_url": candidate.hosted_url,
        "source_url": request.full_url,
        "width": processed.width,
        "height": processed.height,
        "cached": False,
    }
    if candidate.hosted_url:
        cache.set_json(key, payload)
    if not candidate.hosted_url:
        raise HTTPException(
            status_code=503, detail="storage is not configured on the image service"
        )
    return JSONResponse(payload)


@app.get("/")
async def root() -> dict:
    return {
        "service": "multiverse-product-image-search",
        "docs": "/docs",
        "endpoints": ["/health", "/search", "/resolve", "/host"],
    }
