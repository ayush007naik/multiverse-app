"""Image search providers.

Two providers work with no credentials (Wikimedia Commons and Openverse) so
the service is useful out of the box. Google Images (SerpAPI / Custom Search)
and Pexels give noticeably closer matches for packaged goods and are enabled
automatically when their key is present.

Every provider returns raw candidates; ranking and relevance live in
``scoring.py`` so a new source plugs in without touching the ranking rules.
"""

import asyncio
import html
import re
from typing import Awaitable, Callable, Dict, List, Optional, Set, Tuple

import httpx

from . import textutil
from .config import Config
from .models import ImageCandidate, ProductQuery, QueryTier

_TAG_RE = re.compile(r"<[^>]+>")
_WIKIMEDIA_MIME = {"image/jpeg", "image/png", "image/webp"}
# Camera dumps carry no information about what is in the picture.
_GENERIC_FILE_NAME = re.compile(
    r"^(img|image|dsc|dscn|pxl|photo|p|untitled|screenshot|wx)[ _-]*\d*$", re.IGNORECASE
)
# Licenses that oblige us to credit the author on the product page.
_ATTRIBUTION_LICENSES = re.compile(r"(^|[^A-Z])CC[ -]?BY", re.IGNORECASE)


def _strip_html(value: str) -> str:
    return html.unescape(_TAG_RE.sub(" ", value or "")).strip()


def _attribution(creator: str, license_name: str) -> str:
    parts = [p for p in (creator.strip(), license_name.strip()) if p]
    return " · ".join(parts)


# ---------------------------------------------------------------------------
# Query construction
# ---------------------------------------------------------------------------

def _join(*phrases: str) -> str:
    """Joins phrases while dropping words already present.

    Without this, a sheet row of name "Amul Butter" + brand "Amul" produces the
    query "amul amul butter", which every provider ranks worse.
    """
    out: List[str] = []
    seen = set()
    for phrase in phrases:
        for word in (phrase or "").split():
            if word in seen:
                continue
            seen.add(word)
            out.append(word)
    return " ".join(out)


def relaxed_product(product: ProductQuery) -> ProductQuery:
    """A shorter target used for a second pass when the first finds nothing.

    Photo encyclopaedias match short, concrete phrases. A sheet row of
    "Colgate Strong Teeth Toothpaste 150g" by brand "Colgate" returns zero
    hits, while "Colgate Toothpaste" returns twenty product shots.

    The brand is kept, because it is what stops a relaxed match from being the
    wrong product, and so is the *head noun* -- the product type, which is the
    last non-numeric word of the name ("...Toothpaste", "...Biscuit"). Sizes
    are dropped because a number matches nothing.
    """
    core = textutil.strip_variant(product.name, product.variant)
    core_tokens = [t for t in textutil.tokens(core) if not t.isdigit()]
    if len(core_tokens) <= 2:
        return product  # already short; a retry would repeat the same search
    keep = 1 if product.brand.strip() else 2
    return ProductQuery(
        name=" ".join(core_tokens[-keep:]),
        brand=product.brand,
        category=product.category,
    )


def generic_product(product: ProductQuery) -> ProductQuery:
    """The product named without its brand, for a last-resort third pass.

    A brand is only in a free photo library if somebody happened to upload that
    brand. Wikimedia has photographs of steel rods and none of JSW Steel, so
    every query carrying "JSW" returns nothing at all and the row stays blank
    no matter how well the results that did come back were scored. Dropping the
    brand asks the question the library can actually answer: is there a
    photograph of a *TMT bar*?

    Two words are kept, because one rarely identifies a product -- "bar" also
    matches a crowbar. The brand is cleared from the field rather than only
    from the query text, so neither ``build_queries`` nor a later pass can put
    it back.

    Returns the product untouched when the name yields no tokens to work with,
    which makes the tier a no-op rather than a brand-free search for nothing.
    """
    core = textutil.strip_variant(product.name, product.variant)
    core_tokens = [t for t in textutil.tokens(core) if not t.isdigit()]
    if not core_tokens:
        return product
    return ProductQuery(
        name=" ".join(core_tokens[-2:]),
        brand="",
        category=product.category,
    )


def asked_queries(product: ProductQuery, max_queries: int = 3) -> Set[str]:
    """The query strings a tier would send, normalised for comparison."""
    return {
        q.lower().strip()
        for q in build_queries(product, max_queries=max_queries)
    }


def asks_something_new(
    product: ProductQuery, max_queries: int, asked: Set[str]
) -> bool:
    """False when every query this tier would send has already been sent.

    A sheet row usually repeats its brand inside the name, so clearing the brand
    field often leaves the query string byte-for-byte identical: "Exide Battery"
    carries "Exide" twice, and "Domino's Pizza" searches as "dominos pizza"
    either way. Without this check the third pass would re-ask a question that
    was already answered, spend the provider quota on it, and return the same
    rows it had before.
    """
    return bool(asked_queries(product, max_queries) - asked)


def build_queries(product: ProductQuery, max_queries: int = 3) -> List[str]:
    """Ordered search strings, most specific first.

    The size is only added when the name does not already carry it, and the
    brand is never repeated.
    """
    core = textutil.strip_variant(product.name, product.variant)
    core_phrase = textutil.name_phrase(core or product.name)
    full_phrase = textutil.name_phrase(product.name)
    brand_phrase = textutil.name_phrase(product.brand)
    extra = textutil.name_phrase(product.subcategory) or textutil.name_phrase(
        product.category
    )

    tightest = _join(brand_phrase, core_phrase)
    widest = _join(brand_phrase, full_phrase, extra)

    queries: List[str] = []
    if product.barcode and len(product.barcode) >= 8:
        queries.append(product.barcode.strip())

    if brand_phrase:
        queries.append(tightest)
        if widest != tightest:
            queries.append(widest)
    else:
        # Without a brand the category noun is worth more than a tighter
        # phrase: "Butter" alone returns food photography, "Butter Dairy" is
        # at least in the right aisle.
        queries.append(widest)
        queries.append(tightest)

    seen = set()
    out: List[str] = []
    for query in queries:
        key = query.lower().strip()
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(query.strip())
        if len(out) >= max_queries:
            break

    if not out:
        # Every phrase above is built from cleaned text. When that text is
        # empty -- a name written entirely in a script the cleaner does not
        # keep, or a row of nothing but punctuation -- the list came back
        # empty and no provider was called at all, so the row silently
        # matched nothing. Hand the providers the raw text instead: engines
        # handle non-Latin scripts themselves, and a rough query beats none.
        for raw in (product.name, product.brand, product.subcategory, product.category):
            raw = (raw or "").strip()
            if raw:
                return [raw]
    return out


# ---------------------------------------------------------------------------
# Providers
# ---------------------------------------------------------------------------

async def _serpapi(client: httpx.AsyncClient, query: str, limit: int) -> List[ImageCandidate]:
    params = {
        "engine": "google_images",
        "q": query,
        "num": min(20, max(5, limit)),
        "tbm": "isch",
        "safe": "active",
        "hl": "en",
        "api_key": Config.SERPAPI_KEY,
    }
    response = await client.get("https://serpapi.com/search.json", params=params)
    response.raise_for_status()
    payload = response.json()
    out: List[ImageCandidate] = []
    for item in payload.get("images_results", []) or []:
        full = item.get("original") or ""
        if not full:
            continue
        variants = item.get("images") or []
        width = item.get("original_width") or item.get("width")
        height = item.get("original_height") or item.get("height")
        if variants:
            biggest = max(
                variants,
                key=lambda v: (v.get("width") or 0) * (v.get("height") or 0),
            )
            width = biggest.get("width") or width
            height = biggest.get("height") or height
        out.append(
            ImageCandidate(
                full_url=full,
                thumbnail_url=item.get("thumb") or full,
                title=item.get("title") or "",
                tags=" ".join(str(v) for v in (item.get("source") or []) if v),
                source="serpapi",
                source_page=item.get("link"),
                width=width,
                height=height,
            )
        )
    return out


async def _google_cse(client: httpx.AsyncClient, query: str, limit: int) -> List[ImageCandidate]:
    params = {
        "key": Config.GOOGLE_CSE_KEY,
        "cx": Config.GOOGLE_CSE_CX,
        "q": query,
        "searchType": "image",
        "num": min(10, max(1, limit)),
        "safe": "active",
    }
    response = await client.get(
        "https://www.googleapis.com/customsearch/v1", params=params
    )
    response.raise_for_status()
    payload = response.json()
    out: List[ImageCandidate] = []
    for item in payload.get("items", []) or []:
        image = item.get("image") or {}
        context = image.get("contextLink") or ""
        full = image.get("contentLink") or context
        if not full:
            continue
        out.append(
            ImageCandidate(
                full_url=full,
                thumbnail_url=image.get("thumbnailLink") or full,
                title=item.get("title") or "",
                tags=context,
                source="google_cse",
                source_page=item.get("link") or context,
                width=None,
                height=None,
            )
        )
    return out


async def _pexels(client: httpx.AsyncClient, query: str, limit: int) -> List[ImageCandidate]:
    response = await client.get(
        "https://api.pexels.com/v1/search",
        params={"query": query, "per_page": min(20, max(5, limit)), "orientation": "squarish"},
        headers={"Authorization": Config.PEXELS_API_KEY},
    )
    response.raise_for_status()
    payload = response.json()
    out: List[ImageCandidate] = []
    for photo in payload.get("photos", []) or []:
        src = photo.get("src") or {}
        full = src.get("large2x") or src.get("large") or src.get("original")
        if not full:
            continue
        out.append(
            ImageCandidate(
                full_url=full,
                thumbnail_url=src.get("medium") or src.get("small") or full,
                title=photo.get("alt") or "",
                tags=f"{photo.get('alt') or ''} {photo.get('photographer') or ''}",
                source="pexels",
                source_page=photo.get("url"),
                attribution=_attribution(
                    photo.get("photographer") or "", "Pexels License"
                ),
                width=photo.get("width"),
                height=photo.get("height"),
            )
        )
    return out


async def _unsplash(client: httpx.AsyncClient, query: str, limit: int) -> List[ImageCandidate]:
    response = await client.get(
        "https://api.unsplash.com/search/photos",
        params={"query": query, "per_page": min(20, max(5, limit)), "orientation": "squarish"},
        headers={"Authorization": f"Client-ID {Config.UNSPLASH_ACCESS_KEY}"},
    )
    response.raise_for_status()
    payload = response.json()
    out: List[ImageCandidate] = []
    for photo in payload.get("results", []) or []:
        urls = photo.get("urls") or {}
        full = urls.get("full") or urls.get("raw") or urls.get("regular")
        if not full:
            continue
        user = photo.get("user") or {}
        description = photo.get("alt_description") or photo.get("description") or ""
        out.append(
            ImageCandidate(
                full_url=full,
                thumbnail_url=urls.get("small") or full,
                title=description[:200],
                tags=f"{description} {photo.get('description') or ''}",
                source="unsplash",
                source_page=(photo.get("links") or {}).get("html"),
                attribution=_attribution(user.get("name") or "", "Unsplash License"),
                width=photo.get("width"),
                height=photo.get("height"),
            )
        )
    return out


async def _wikimedia(client: httpx.AsyncClient, query: str, limit: int) -> List[ImageCandidate]:
    params = {
        "action": "query",
        "format": "json",
        "formatversion": "1",
        "generator": "search",
        "gsrsearch": f"{query} filetype:bitmap",
        "gsrnamespace": "6",
        "gsrlimit": min(50, max(5, limit)),
        "prop": "imageinfo",
        "iiprop": "url|size|mime|extmetadata",
        "iiurlwidth": "600",
    }
    response = await client.get(
        "https://commons.wikimedia.org/w/api.php", params=params
    )
    response.raise_for_status()
    pages = ((response.json().get("query") or {}).get("pages") or {})
    out: List[ImageCandidate] = []
    for page in pages.values():
        for info in page.get("imageinfo") or []:
            if info.get("mime") not in _WIKIMEDIA_MIME:
                continue
            full = info.get("url")
            if not full:
                continue
            meta = info.get("extmetadata") or {}

            def meta_text(key: str) -> str:
                return _strip_html((meta.get(key) or {}).get("value", ""))

            file_name = (page.get("title") or "").removeprefix("File:").removeprefix("Image:")
            stem = file_name.rsplit(".", 1)[0]
            description = meta_text("ImageDescription")
            # The file name identifies the image; the description is prose
            # about it. Scoring weighs them differently, so keep them apart —
            # and fall back to the description when the name is a camera dump
            # such as "IMG_4021.jpg".
            title = stem if not _GENERIC_FILE_NAME.match(stem.strip()) else description
            license_name = meta_text("LicenseShortName")
            out.append(
                ImageCandidate(
                    full_url=full,
                    thumbnail_url=info.get("thumburl") or full,
                    title=title or stem,
                    tags=f"{file_name} {description} {meta_text('Categories')}",
                    source="wikimedia",
                    source_page=info.get("descriptionurl"),
                    license=license_name or None,
                    attribution=_attribution(meta_text("Artist"), license_name) or None,
                    requires_attribution=bool(
                        license_name and _ATTRIBUTION_LICENSES.search(license_name)
                    ),
                    width=info.get("width"),
                    height=info.get("height"),
                )
            )
    return out


async def _open_food_facts(
    client: httpx.AsyncClient, product: ProductQuery, query: str
) -> List[ImageCandidate]:
    """Open Food Facts: a keyless database of real grocery products.

    This is the strongest source available without an API key, and the only one
    that answers with an actual photograph *of the item* rather than a
    photograph that happens to contain it. Barcodes resolve to the exact SKU;
    everything else falls back to a full-text search over the database.

    OFF rate-limits aggressively and answers a throttled request with an HTML
    error page rather than a status code, so a non-JSON body is retried with a
    backoff. Only once the retries are exhausted does this raise, which
    :func:`search_all` reports as a provider error rather than as an empty
    result set.
    """
    code = re.sub(r"\D", "", product.barcode or "")
    if len(code) >= 8:
        payload = await _off_json(
            client,
            "https://world.openfoodfacts.org/api/v2/product",
            params={"fields": _OFF_FIELDS},
            path=f"{code}.json",
        )
        products = [(payload or {}).get("product")] if payload else []
    else:
        payload = await _off_json(
            client,
            "https://world.openfoodfacts.org/cgi/search.pl",
            params={
                "search_terms": query,
                "json": "1",
                "page_size": str(Config.RESULTS_PER_QUERY),
                "fields": _OFF_FIELDS,
            },
        )
        products = (payload or {}).get("products") or []

    out: List[ImageCandidate] = []
    for item in products:
        if not isinstance(item, dict):
            continue
        full = item.get("image_front_url") or item.get("image_url")
        if not full:
            continue
        brand = (item.get("brands") or "").split(",")[0].strip()
        name = (item.get("product_name") or "").strip()
        title = textutil.clean(f"{brand} {name}".strip()) or name
        out.append(
            ImageCandidate(
                full_url=full,
                thumbnail_url=_off_thumbnail(full),
                title=title,
                tags=" ".join(
                    str(v)
                    for v in (item.get("quantity"), item.get("categories"))
                    if v
                ),
                source="openfoodfacts",
                source_page=f"https://world.openfoodfacts.org/product/{item.get('code')}"
                if item.get("code")
                else None,
                license="ODbL",
                attribution=_attribution("Open Food Facts contributors", "ODbL"),
                requires_attribution=True,
            )
        )
    return out


async def _openverse(client: httpx.AsyncClient, query: str, limit: int) -> List[ImageCandidate]:
    headers = {"User-Agent": Config.USER_AGENT}
    if Config.OPENVERSE_TOKEN:
        headers["Authorization"] = f"Bearer {Config.OPENVERSE_TOKEN}"
    response = await client.get(
        "https://api.openverse.org/v1/images/",
        params={
            "q": query,
            "page_size": min(20, max(5, limit)),
            "mature": "false",
            "category": "photograph",
        },
        headers=headers,
    )
    response.raise_for_status()
    payload = response.json()
    out: List[ImageCandidate] = []
    for item in payload.get("results", []) or []:
        full = item.get("url")
        if not full:
            continue
        license_name = item.get("license") or ""
        creator = item.get("creator") or ""
        out.append(
            ImageCandidate(
                full_url=full,
                thumbnail_url=item.get("thumbnail") or full,
                title=item.get("title") or "",
                tags=" ".join(
                    [t.get("display_name", "") for t in (item.get("tags") or [])]
                ),
                source="openverse",
                source_page=item.get("foreign_landing_url"),
                license=license_name or None,
                attribution=_attribution(creator, license_name) or None,
                requires_attribution=bool(_ATTRIBUTION_LICENSES.search(license_name)),
                width=item.get("width"),
                height=item.get("height"),
            )
        )
    return out


ProviderFn = Callable[[httpx.AsyncClient, str, int], Awaitable[List[ImageCandidate]]]

# Open Food Facts fields worth fetching. Images and the name carry the match;
# `quantity` and `categories` help disambiguate a 500g pack from a 200g one.
_OFF_FIELDS = (
    "code,product_name,brands,quantity,categories,image_front_url,image_url"
)
# OFF image names end in ".<width>.jpg"; swapping the width gives the CDN a
# cheap thumbnail instead of pulling a full-resolution shot into a grid tile.
_OFF_SIZE_RE = re.compile(r"\.(\d{2,4})\.jpg$", re.IGNORECASE)
# A throttled OFF request returns HTML with a 200 or a 503, so the body has to
# be parsed to know whether it is usable, and the only remedy is to back off
# and ask again. Measured against the live API, roughly every other anonymous
# request is throttled, so a single retry is not enough to make imports
# reliable.
_OFF_RETRY_AFTER_SECONDS = 1.2
_OFF_MAX_ATTEMPTS = 3


class ProviderUnavailable(Exception):
    """A provider failed in a way that is not the same as "no such product".

    Reported as a provider error rather than as an empty result set, so a
    throttled or broken provider is never mistaken for a product that simply
    has no photograph anywhere.
    """


async def _off_json(
    client: httpx.AsyncClient, url: str, params: dict, path: str = ""
) -> Optional[dict]:
    """GETs Open Food Facts, retrying a throttled request with a backoff.

    Raises :class:`ProviderUnavailable` when every attempt was throttled. A
    404 is a real "no such product" and returns None; a rate limit is not, and
    reporting it as an empty result made a throttled import indistinguishable
    from a catalogue of products that genuinely have no photo.
    """
    last = "no usable response"
    for attempt in range(_OFF_MAX_ATTEMPTS):
        if attempt:
            await asyncio.sleep(_OFF_RETRY_AFTER_SECONDS * (2 ** (attempt - 1)))
        try:
            response = await client.get(f"{url}/{path}" if path else url, params=params)
        except httpx.HTTPError as exc:
            last = f"network error: {exc}"
            continue
        if response.status_code == 404:
            return None  # a real "no such product", not a failure
        if response.status_code >= 500:
            last = f"HTTP {response.status_code} (rate limited)"
            continue
        try:
            payload = response.json()
        except ValueError:
            last = f"HTTP {response.status_code} with a non-JSON body"
            continue
        return payload if isinstance(payload, dict) else None
    raise ProviderUnavailable(f"open food facts {last} after {_OFF_MAX_ATTEMPTS} attempts")


def _off_thumbnail(url: str) -> str:
    return _OFF_SIZE_RE.sub(".400.jpg", url, count=1) if ".jpg" in url.lower() else url


REGISTRY: Dict[str, ProviderFn] = {
    "serpapi": _serpapi,
    "google_cse": _google_cse,
    "pexels": _pexels,
    "unsplash": _unsplash,
    "openfoodfacts": _open_food_facts,  # keyed on the product, not the query
    "wikimedia": _wikimedia,
    "openverse": _openverse,
}

_CREDENTIALS: Dict[str, Callable[[], bool]] = {
    "serpapi": lambda: bool(Config.SERPAPI_KEY),
    "google_cse": lambda: bool(Config.GOOGLE_CSE_KEY and Config.GOOGLE_CSE_CX),
    "pexels": lambda: bool(Config.PEXELS_API_KEY),
    "unsplash": lambda: bool(Config.UNSPLASH_ACCESS_KEY),
    "openfoodfacts": lambda: True,
    "wikimedia": lambda: True,
    "openverse": lambda: True,
}


def available_providers() -> List[str]:
    return [p for p in Config.PROVIDER_ORDER if _CREDENTIALS.get(p, lambda: False)()]


# Providers that are handed the whole product rather than a search phrase,
# because they look a product up in a database instead of querying an index.
PRODUCT_SCOPED = {"openfoodfacts"}


async def search_all(
    client: httpx.AsyncClient,
    product: ProductQuery,
    max_queries: int = 3,
    tier: QueryTier = "branded",
) -> Tuple[List[ImageCandidate], Dict[str, dict]]:
    """Runs every provider over every query concurrently.

    Returns ``(candidates, status)`` where status maps provider id to a small
    dict describing the outcome, which the API surfaces for debugging.

    ``tier`` names the query set being sent and is stamped onto every result.
    It is set here and nowhere else because only this function knows which
    questions were asked; the scoring rules need it to tell a missed brand
    apart from a brand that was deliberately left out of the search.
    """
    queries = build_queries(product, max_queries=max_queries)
    providers = available_providers()
    status: Dict[str, dict] = {}

    tasks = []
    index: List[tuple] = []
    for provider in providers:
        fn = REGISTRY[provider]
        if provider in PRODUCT_SCOPED:
            # These answer from a product database, so they take the product
            # itself and run once: repeating them per query would re-ask the
            # same database the same question.
            tasks.append(fn(client, product, queries[0] if queries else product.name))
            index.append((provider, queries[0] if queries else product.name))
            continue
        for query in queries:
            tasks.append(fn(client, query, Config.RESULTS_PER_QUERY))
            index.append((provider, query))

    if not tasks:
        return [], status

    settled = await asyncio.gather(*tasks, return_exceptions=True)

    by_provider: Dict[str, List[ImageCandidate]] = {p: [] for p in providers}
    errors: Dict[str, List[str]] = {}
    for (provider, query), outcome in zip(index, settled):
        if isinstance(outcome, BaseException):
            errors.setdefault(provider, []).append(f"{query}: {outcome}")
            continue
        by_provider.setdefault(provider, []).extend(outcome or [])

    candidates: List[ImageCandidate] = []
    for results in by_provider.values():
        for candidate in results:
            candidate.tier = tier
    for provider in providers:
        found = by_provider.get(provider) or []
        if found:
            status[provider] = {"ok": True, "count": len(found)}
            candidates.extend(found)
            continue
        # A provider that answered with zero hits is healthy, not broken; only
        # a raised exception counts as a failure.
        status[provider] = {
            "ok": not errors.get(provider),
            "count": 0,
            **({"errors": errors[provider]} if errors.get(provider) else {}),
        }

    return candidates, status
