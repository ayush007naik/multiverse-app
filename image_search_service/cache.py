"""SQLite-backed cache.

Two things are worth remembering across requests:

* provider responses for a query — vendors import the same catalogue twice
  and hundreds of rows can reference the same product;
* the hosted URL of an image we already downloaded and re-uploaded, keyed by
  the source URL, so a re-import costs a hash lookup instead of a download.

Content is addressed, so the cache is safe to share between processes.
"""

import hashlib
import json
import os
import sqlite3
import threading
import time
from typing import Any, List, Optional

_SCHEMA = """
CREATE TABLE IF NOT EXISTS entries (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    created_at REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_entries_created ON entries(created_at);
"""

_lock = threading.RLock()  # reentrant: purge_expired -> _db() nests locks
_conn: Optional[sqlite3.Connection] = None


def _db() -> sqlite3.Connection:
    global _conn
    if _conn is not None:
        return _conn
    with _lock:
        if _conn is None:
            path = os.environ.get("CACHE_PATH") or ":memory:"
            if path != ":memory:":
                os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
            _conn = sqlite3.connect(path, check_same_thread=False)
            _conn.execute("PRAGMA journal_mode=WAL")
            _conn.executescript(_SCHEMA)
            _conn.commit()
    return _conn


def make_key(namespace: str, value: str) -> str:
    digest = hashlib.sha1(value.encode("utf-8")).hexdigest()
    return f"{namespace}:{digest}"


def get_json(key: str, ttl: int) -> Optional[Any]:
    try:
        row = _db().execute(
            "SELECT value, created_at FROM entries WHERE key = ?", (key,)
        ).fetchone()
    except sqlite3.Error:
        return None
    if not row:
        return None
    value, created_at = row
    if ttl > 0 and (time.time() - created_at) > ttl:
        return None
    try:
        return json.loads(value)
    except (TypeError, ValueError):
        return None


def set_json(key: str, value: Any) -> None:
    try:
        with _lock:
            _db().execute(
                "INSERT OR REPLACE INTO entries (key, value, created_at) VALUES (?,?,?)",
                (key, json.dumps(value), time.time()),
            )
            _db().commit()
    except (sqlite3.Error, TypeError, ValueError):
        pass


def purge_expired(ttl: int) -> int:
    """Drops entries older than the TTL. Safe to call on a schedule."""
    try:
        with _lock:
            cur = _db().execute(
                "DELETE FROM entries WHERE created_at < ?", (time.time() - ttl,)
            )
            _db().commit()
            return cur.rowcount or 0
    except sqlite3.Error:
        return 0
