#!/bin/bash
# FALLBACK ONLY. The service lives on Cloud Run at a stable URL, and that URL is
# compiled into the app, so a release build needs no flags at all:
#
#   cd vendor_dashboard
#   flutter build apk --release
#
# Use this script only when you need to run the service locally, e.g. to change
# the search code without redeploying. It publishes this Mac over a Cloudflare
# quick tunnel, which changes URL on every run and needs the Mac awake.
#
# Usage:  ./image_search_service/run_public.sh
# Then:   cd vendor_dashboard
#         flutter run --release --dart-define=IMAGE_SEARCH_URL=<printed url>

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-8000}"
LOG="/tmp/image_search_service.log"
TUNNEL_LOG="/tmp/image_search_tunnel.log"
CLOUDFLARED="${CLOUDFLARED:-/var/folders/sg/7nl58lk51h59v56z02pdddwh0000gn/T/opencode/cloudflared}"

if [ ! -x "$CLOUDFLARED" ]; then
  echo "cloudflared not found at $CLOUDFLARED" >&2
  echo "Download it with:" >&2
  echo "  curl -sL -o /tmp/cf.tgz https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64.tgz" >&2
  echo "  tar xzf /tmp/cf.tgz -C <dir> && chmod +x <dir>/cloudflared" >&2
  exit 1
fi

# --- service -------------------------------------------------------------
pkill -f "uvicorn image_search_service.main:app" 2>/dev/null || true
sleep 1
cd "$ROOT"
nohup "$HERE/.venv/bin/python" -m uvicorn image_search_service.main:app \
  --host 127.0.0.1 --port "$PORT" > "$LOG" 2>&1 &
echo "service starting on 127.0.0.1:$PORT (log: $LOG)"

for _ in $(seq 1 30); do
  if curl -sf -m 2 "http://127.0.0.1:$PORT/health" > /dev/null; then
    echo "service is healthy"
    break
  fi
  sleep 1
done

# --- public tunnel -------------------------------------------------------
pkill -f "cloudflared tunnel" 2>/dev/null || true
sleep 1
nohup "$CLOUDFLARED" tunnel --url "http://127.0.0.1:$PORT" \
  --no-autoupdate > "$TUNNEL_LOG" 2>&1 &

URL=""
for _ in $(seq 1 40); do
  URL="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" | head -1 || true)"
  [ -n "$URL" ] && break
  sleep 1
done

if [ -z "$URL" ]; then
  echo "tunnel did not come up, see $TUNNEL_LOG" >&2
  exit 1
fi

# The tunnel URL is deliberately NOT written to image_search_config.json. That
# file is the production endpoint (the one compiled into the app by default and
# the one deploy_cloudrun.sh keeps in step), and a dead tunnel URL left in it
# would outlive this script and point a release build at nothing.

echo
echo "  public image service: $URL"
echo
echo "  cd vendor_dashboard"
echo "  flutter run --release --dart-define=IMAGE_SEARCH_URL=$URL"
echo
echo "  This tunnel URL changes every time you run the script, so the build must"
echo "  pass it explicitly -- the compiled-in default is the production service."
echo "  Keep this Mac awake and online while it is in use."
