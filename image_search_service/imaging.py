"""Downloading, validating and normalising candidate images.

Provider metadata lies: a result may claim 2000x2000 and actually be a 40px
sprite, or point at an HTML error page. Every image is therefore opened with
Pillow, checked, and re-encoded to a sane JPEG before being stored. A 64-bit
difference hash is computed at the same time so visually identical results
from different providers collapse into one.
"""

import asyncio
import hashlib
import io
from typing import List, NamedTuple, Optional, Set
from urllib.parse import urlparse

import httpx
from PIL import Image, ImageOps

from .config import Config

# Pillow warns above this and hard-errors above twice it. Set to twice the real
# budget so that an image which is merely too big is refused by
# _check_pixel_budget with a plain "too many pixels" message, instead of
# tripping Pillow's "decompression bomb DOS attack" warning first. A security
# warning on an ordinary oversized photo trains operators to ignore the real
# one. Pillow's error stays as a backstop well above the budget.
Image.MAX_IMAGE_PIXELS = Config.MAX_DECODE_PIXELS * 2

_ACCEPTED_FORMATS = {"JPEG", "PNG", "WEBP", "BMP", "GIF", "MPO"}


class ProcessedImage(NamedTuple):
    jpeg: bytes
    width: int
    height: int
    dhash: int
    content_hash: str


class ImageRejected(Exception):
    pass


def _check_url(url: str) -> None:
    """Rejects anything that is not a plain http(s) URL.

    /host takes its URL straight from the grid, so it has to survive whatever a
    provider or a hand-edited request put there. An empty string, a bare path
    or a "javascript:" URL made httpx raise a bare ValueError from urllib,
    which is not an HTTPError and so escaped every handler as a 500. Checking
    the scheme here also keeps the service from being pointed at file:// or an
    internal address by a crafted request.
    """
    try:
        parsed = urlparse(url)
    except ValueError as exc:
        raise ImageRejected(f"unusable url: {exc}") from exc
    if parsed.scheme not in ("http", "https"):
        raise ImageRejected(f"not an http(s) url: {url[:80]!r}")
    if not parsed.netloc:
        raise ImageRejected(f"url has no host: {url[:80]!r}")


async def _fetch(client: httpx.AsyncClient, url: str) -> bytes:
    _check_url(url)
    async with client.stream("GET", url) as response:
        if response.status_code >= 400:
            raise ImageRejected(f"HTTP {response.status_code}")
        chunks = bytearray()
        async for chunk in response.aiter_bytes():
            chunks.extend(chunk)
            if len(chunks) > Config.DOWNLOAD_MAX_BYTES:
                raise ImageRejected("image too large")
        if not chunks:
            raise ImageRejected("empty body")
        return bytes(chunks)


def _check_pixel_budget(size: tuple) -> None:
    """Rejects an over-large image from its header, before decoding it.

    Checked on ``(width, height)`` straight after ``Image.open``, which only
    reads the header. ``load`` is what allocates the pixel buffer, so testing
    the budget afterwards would mean allocating 300MB in order to decide the
    image is too big.
    """
    width, height = size
    pixels = width * height
    if pixels > Config.MAX_DECODE_PIXELS:
        raise ImageRejected(f"too many pixels ({width}x{height})")


def _decode_and_check(data: bytes) -> Image.Image:
    try:
        image = Image.open(io.BytesIO(data))
    except Exception as exc:  # Pillow raises a wide range of errors here
        raise ImageRejected(f"undecodable image: {exc}") from exc

    _check_pixel_budget(image.size)

    try:
        image.load()
    except Exception as exc:  # includes DecompressionBombError
        raise ImageRejected(f"undecodable image: {exc}") from exc

    if image.format not in _ACCEPTED_FORMATS:
        raise ImageRejected(f"unsupported format {image.format}")

    if image.mode in ("RGBA", "LA", "P"):
        # Flatten transparency onto white; catalogue cards are never transparent.
        image = image.convert("RGBA")
        background = Image.new("RGB", image.size, (255, 255, 255))
        background.paste(image, mask=image.split()[-1])
        image = background
    elif image.mode != "RGB":
        image = image.convert("RGB")

    return ImageOps.exif_transpose(image)


def _validate(image: Image.Image) -> None:
    width, height = image.size

    # The long edge is what decides whether an image is usable, and it is what
    # scoring._quality_factor already measures. Requiring *both* edges to clear
    # the bar rejected every portrait product shot: Open Food Facts' "400px" is
    # a long-edge cap, so a 213x400 pack shot failed a 220px short-edge test.
    # Those results still scored well, so the service reported them, then
    # refused to host them and quietly left the product hotlinking the provider.
    if max(width, height) < Config.MIN_EDGE_PX:
        raise ImageRejected(f"too small ({width}x{height})")

    # One enormous edge and nothing else is still not a usable picture.
    if width * height < Config.MIN_IMAGE_PIXELS:
        raise ImageRejected(f"too little detail ({width}x{height})")


def _resize(image: Image.Image) -> Image.Image:
    """Caps the long edge and never upscales."""
    width, height = image.size
    limit = Config.TARGET_MAX_EDGE_PX
    if max(width, height) <= limit:
        return image
    if width >= height:
        new_size = (limit, max(1, round(height * limit / width)))
    else:
        new_size = (max(1, round(width * limit / height)), limit)
    return image.resize(new_size, Image.LANCZOS)


def _difference_hash(image: Image.Image) -> int:
    """64-bit dHash: robust enough to spot the same photo re-encoded."""
    grayscale = image.convert("L").resize((9, 8), Image.LANCZOS)
    pixels = list(grayscale.getdata())
    bits = 0
    for row in range(8):
        offset = row * 9
        for col in range(8):
            bits = (bits << 1) | (1 if pixels[offset + col] > pixels[offset + col + 1] else 0)
    return bits


def _encode(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=Config.JPEG_QUALITY, optimize=True)
    data = buffer.getvalue()
    if len(data) > Config.MAX_UPLOAD_BYTES:
        raise ImageRejected("normalised image exceeds the upload limit")
    return data


def process(data: bytes) -> ProcessedImage:
    """Validates, resizes and re-encodes raw image bytes."""
    image = _decode_and_check(data)
    _validate(image)
    image = _resize(image)
    jpeg = _encode(image)
    return ProcessedImage(
        jpeg=jpeg,
        width=image.size[0],
        height=image.size[1],
        dhash=_difference_hash(image),
        content_hash=hashlib.sha1(jpeg).hexdigest(),
    )


async def download_and_process(
    client: httpx.AsyncClient, url: str
) -> Optional[ProcessedImage]:
    """Best-effort: returns None instead of raising so one bad URL in a grid
    of candidates cannot fail the whole request.

    The URL is caller-supplied and untrusted, and the HTTP stack behind it
    raises more than httpx.HTTPError for a malformed target, so the catch is
    deliberately wider than the transport errors alone.
    """
    try:
        data = await _fetch(client, url)
        return process(data)
    except (ImageRejected, httpx.HTTPError, asyncio.TimeoutError, OSError, ValueError):
        return None


def hamming(left: int, right: int) -> int:
    return bin(left ^ right).count("1")


def is_duplicate(left: ProcessedImage, seen: Set[int], threshold: int = 6) -> bool:
    return any(hamming(left.dhash, other) <= threshold for other in seen)


def pick_best_distinct(
    processed: List[ProcessedImage],
) -> Optional[ProcessedImage]:
    """First entry, skipping near-duplicates of the ones already chosen."""
    seen: Set[int] = set()
    for item in processed:
        if not is_duplicate(item, seen):
            seen.add(item.dhash)
            return item
    return processed[0] if processed else None
