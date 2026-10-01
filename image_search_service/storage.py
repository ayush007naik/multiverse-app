"""Uploads matched images into Supabase Storage.

Product images are re-hosted rather than hot-linked: provider thumbnails are
rate limited, several forbid hot linking, and the URLs would break the moment
a provider reorganises its CDN. Paths are content addressed, so the same photo
found for two vendors is stored once and shared by the whole catalog.

    global_products/auto/<sha1>.jpg
    global_products/<globalProductId>/auto_<sha1>.jpg   (when a folder is given)
"""

import posixpath
import re
from typing import Optional
from urllib.parse import quote

import httpx

from .config import Config

_SAFE_SEGMENT = re.compile(r"[^A-Za-z0-9_-]+")


class StorageError(Exception):
    pass


def _sanitize_segment(value: str) -> str:
    """Returns '' for anything that is not a plain path segment."""
    return _SAFE_SEGMENT.sub("-", (value or "").strip()).strip("-")[:80]


def object_path(content_hash: str, folder: Optional[str] = None) -> str:
    """Deterministic object path so repeat uploads are no-ops.

    [folder] comes from a caller-supplied global product id, so segments that
    are not plain names ("..", "", "%2e%2e") are dropped rather than escaped.
    """
    name = f"auto_{content_hash}.jpg"
    if folder:
        parts = [_sanitize_segment(p) for p in folder.split("/") if p.strip()]
        parts = [p for p in parts if p]
        if parts:
            return "/".join(parts + [name])
    return posixpath.join("auto", f"{content_hash}.jpg")


def public_url(path: str) -> str:
    base = Config.SUPABASE_URL.rstrip("/")
    encoded = "/".join(quote(segment, safe="") for segment in path.split("/"))
    return f"{base}/storage/v1/object/public/{Config.STORAGE_BUCKET}/{encoded}"


def is_configured() -> bool:
    return bool(Config.SUPABASE_KEY and Config.SUPABASE_URL)


async def upload(
    client: httpx.AsyncClient, path: str, data: bytes, cache_control: str = "31536000"
) -> str:
    """PUTs the bytes into the bucket and returns the public URL."""
    if not is_configured():
        raise StorageError(
            "Supabase storage is not configured; set SUPABASE_ANON_KEY or "
            "SUPABASE_SERVICE_ROLE_KEY."
        )
    encoded = "/".join(quote(segment, safe="") for segment in path.split("/"))
    url = (
        f"{Config.SUPABASE_URL.rstrip('/')}/storage/v1/object/"
        f"{Config.STORAGE_BUCKET}/{encoded}"
    )
    headers = {
        "Authorization": f"Bearer {Config.SUPABASE_KEY}",
        "apikey": Config.SUPABASE_KEY,
        "Content-Type": "image/jpeg",
        "x-upsert": "true",
        "Cache-Control": cache_control,
    }
    response = await client.put(url, content=data, headers=headers)
    if response.status_code >= 400:
        raise StorageError(f"storage upload failed: HTTP {response.status_code} {response.text[:200]}")
    return public_url(path)
