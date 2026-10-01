"""Runtime configuration, read from environment variables.

Nothing secret is hard-coded here. The Supabase *anon* key is acceptable
because the ``global_products`` bucket is public-read and the vendor app
already ships that key; a service-role key can be supplied instead when the
service runs outside a trusted network.
"""

import os


def _str(name: str, default: str = "") -> str:
    value = os.environ.get(name)
    return value.strip() if value else default


def _bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _int(name: str, default: int) -> int:
    try:
        return int(_str(name) or default)
    except (TypeError, ValueError):
        return default


class Config:
    # --- HTTP server -----------------------------------------------------
    HOST = _str("HOST", "0.0.0.0")
    PORT = _int("PORT", 8000)

    # Identifies the service to the free image APIs and to Wikimedia, which
    # rejects requests without a descriptive User-Agent.
    USER_AGENT = _str(
        "USER_AGENT",
        "MultiverseProductImageBot/1.0 (https://multiverse.example; "
        "vendor-dashboard image lookup)",
    )

    # --- Supabase (re-hosting so product images never hotlink) -----------
    SUPABASE_URL = _str("SUPABASE_URL", "https://ufvwjmtfbupnnpbivcxr.supabase.co")
    SUPABASE_KEY = _str("SUPABASE_SERVICE_ROLE_KEY") or _str("SUPABASE_ANON_KEY")
    STORAGE_BUCKET = _str("SUPABASE_STORAGE_BUCKET", "global_products")

    # --- Auth ------------------------------------------------------------
    # Firebase Auth ID tokens are sent by the vendor dashboard. Verification
    # is optional so the service can be exercised locally without Firebase.
    REQUIRE_AUTH = _bool("REQUIRE_AUTH", False)
    FIREBASE_PROJECT_ID = _str("FIREBASE_PROJECT_ID", "multiverses-8d207")

    # --- Optional provider keys (keyless providers always stay on) -------
    SERPAPI_KEY = _str("SERPAPI_KEY")
    GOOGLE_CSE_KEY = _str("GOOGLE_CSE_KEY")
    GOOGLE_CSE_CX = _str("GOOGLE_CSE_CX")
    PEXELS_API_KEY = _str("PEXELS_API_KEY")
    UNSPLASH_ACCESS_KEY = _str("UNSPLASH_ACCESS_KEY")
    # Openverse is far more generous with a token; anonymous use is capped
    # at a handful of requests per hour.
    OPENVERSE_TOKEN = _str("OPENVERSE_TOKEN")

    # --- Search tuning ---------------------------------------------------
    # Comma separated provider ids, in priority order. Unknown ids are
    # ignored and providers without credentials are skipped.
    PROVIDER_ORDER = [
        p.strip()
        for p in _str(
            "PROVIDER_ORDER",
            "openfoodfacts,serpapi,google_cse,pexels,unsplash,wikimedia,openverse",
        ).split(",")
        if p.strip()
    ]
    RESULTS_PER_QUERY = _int("RESULTS_PER_QUERY", 20)
    MAX_CANDIDATES = _int("MAX_CANDIDATES", 24)
    # Candidates scoring below this are not "an exact photo" and are never
    # auto-attached to a product. Anything the service is not confident about
    # is left blank for the vendor to fill or pick by hand.
    #
    # Measured against a live catalogue of common Indian grocery, personal-care
    # and cleaning rows on the keyless providers alone (Open Food Facts,
    # Wikimedia, Openverse), this line put 9 images on 19 products and every
    # one of the 9 was the right product; the rows it holds back were wrong
    # variants ("Tata Salt Lite" for "Tata Salt Iodised", "Dove IIII" for
    # "Dove Beauty Bar") or had no photo in any source at all.
    #
    # It is not 0.90. A genuinely correct match against a real catalogue entry
    # lands between 0.60 and 0.77, because a product database names the item in
    # the manufacturer's words and so collects fewer of the exact-phrase
    # bonuses a web file name would. A 0.90 bar was measured and attaches
    # nothing at all -- every row goes blank, including the ones that were
    # right. Precision is what matters here, not the size of the number.
    MIN_ACCEPT_SCORE = float(_str("MIN_ACCEPT_SCORE", "0.60") or 0.60)
    HTTP_TIMEOUT = float(_str("HTTP_TIMEOUT", "12") or 12)
    MAX_CONCURRENT_HTTP = _int("MAX_CONCURRENT_HTTP", 8)

    # --- Noun aliases -----------------------------------------------------
    # Words that sit *next to* the product's noun in a sheet name and name a
    # different object. A photo of "Three leather belt attachment pouches" shares
    # every word of a "Leather Belt" row except that the subject is the pouch, so
    # it scores 0.77 and attaches confidently. Same for "Face Cream" matched
    # against "Face Cream En Vivo 10 Anos", which is a Mexican banda called En
    # Vivo, not a cosmetic.
    #
    # Only a noun-adjacency case belongs here, never a broad topic word: an
    # earlier attempt at a general head-noun rule caught one wrong image and lost
    # four correct ones ("Puma football ball", "Ferrero Rocher chocolate balls",
    # "haldiram aloo bhujia sev", "Small gift box for Novell employees"), because
    # "hammer drill" and "football ball" are textually indistinguishable from
    # "head of a hammer drill".
    #
    # Key: a word or phrase in the sheet name. Value: words that, appearing in
    # the image, mean the photo is of something else. ``own_words`` is subtracted
    # before the test, so a vendor really selling "Belt Pouch" is untouched, and
    # a hit is capped rather than dropped -- the image stays in the grid for the
    # vendor to accept.
    NOUN_ALIASES = {
        "belt": {"pouch", "pouches"},
        "board": {"sim", "card", "circuit", "module"},
        "face cream": {"banda", "festejo", "en vivo"},
    }

    # --- Image handling --------------------------------------------------
    MAX_UPLOAD_BYTES = _int("MAX_UPLOAD_BYTES", 12 * 1024 * 1024)
    DOWNLOAD_MAX_BYTES = _int("DOWNLOAD_MAX_BYTES", 12 * 1024 * 1024)
    MIN_EDGE_PX = _int("MIN_EDGE_PX", 220)
    # Floor on total pixels, so a sliver with one enormous edge (20x2000) is
    # still refused. 50k is roughly a 200x250 image: enough for a catalogue
    # card, and below the 85k of a portrait pack shot.
    MIN_IMAGE_PIXELS = _int("MIN_IMAGE_PIXELS", 50_000)
    TARGET_MAX_EDGE_PX = _int("TARGET_MAX_EDGE_PX", 1200)
    JPEG_QUALITY = _int("JPEG_QUALITY", 88)
    # Ceiling on how many pixels an image may have before it is rejected. This
    # is the real limit: it is what bounds decode memory. It was previously a
    # long-edge check instead, which threw away a 5472x7296 Wikimedia photo of
    # Colgate toothpaste and most photos from a 24MP or 48MP phone while
    # happily accepting a 20x2000 sprite.
    MAX_DECODE_PIXELS = _int("MAX_DECODE_PIXELS", 60_000_000)

    # --- Cache -----------------------------------------------------------
    CACHE_TTL_SECONDS = _int("CACHE_TTL_SECONDS", 7 * 24 * 3600)
    CACHE_PATH = _str("CACHE_PATH", os.path.join(os.path.dirname(__file__), "cache.sqlite3"))

    @classmethod
    def summary(cls) -> dict:
        """Provider availability, safe to expose on /health."""
        keys = {
            "serpapi": cls.SERPAPI_KEY,
            "google_cse": cls.GOOGLE_CSE_KEY and cls.GOOGLE_CSE_CX,
            "pexels": cls.PEXELS_API_KEY,
            "unsplash": cls.UNSPLASH_ACCESS_KEY,
            "openfoodfacts": True,  # product database, keyless
            "openverse": True,      # works without a token, just rate limited
            "wikimedia": True,
        }
        enabled = [p for p in cls.PROVIDER_ORDER if keys.get(p)]
        return {
            "providers_enabled": enabled,
            "providers_configured_but_skipped": [
                p for p in cls.PROVIDER_ORDER if not keys.get(p)
            ],
            "storage_configured": bool(cls.SUPABASE_KEY),
            "require_auth": cls.REQUIRE_AUTH,
            "min_accept_score": cls.MIN_ACCEPT_SCORE,
        }
