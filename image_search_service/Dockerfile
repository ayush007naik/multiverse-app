FROM python:3.12-slim

WORKDIR /srv

# Dependencies first, so a code change does not re-resolve them.
COPY image_search_service/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# The service is the `image_search_service` package and must be imported from
# its parent directory, because its modules use relative imports
# (`from . import providers`). Copying the package into /srv would break those.
COPY image_search_service ./image_search_service

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080 \
    CACHE_PATH=/tmp/image-search-cache.sqlite3

EXPOSE 8080

# The endpoints the vendor dashboard calls are /search, /resolve and /host.
CMD ["sh", "-c", "uvicorn image_search_service.main:app --host 0.0.0.0 --port ${PORT}"]
