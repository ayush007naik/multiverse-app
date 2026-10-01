#!/bin/bash
# Builds and deploys the product image search service to Cloud Run, then points
# the vendor app's build config at the resulting stable URL.
#
#   cp image_search_service/cloudrun.env.yaml.example image_search_service/cloudrun.env.yaml
#   # fill in FIREBASE_PROJECT_ID (must match firebase_options.dart) and
#   # SUPABASE_SERVICE_ROLE_KEY
#   ./image_search_service/deploy_cloudrun.sh
#
# After this, build the app with:
#   cd vendor_dashboard
#   flutter build apk --release
#
# The app already knows the endpoint, so no --dart-define is required. The URL
# is a Cloud Run domain mapping and does not change between deploys, so the
# built app keeps working; the check at the end refuses to deploy if the Dart
# source's compiled-in default has drifted from the deployed URL.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

PROJECT="${PROJECT:-multiverses-8d207}"
REGION="${REGION:-asia-south1}"
SERVICE="${SERVICE:-multiverse-image-search}"
IMAGE="gcr.io/${PROJECT}/${SERVICE}"
# NOTE: the file must NOT be named *.env. gcloud picks the parser from the
# extension -- a path ending in .env is read as dotenv (KEY=VALUE), and the YAML
# below then parses to an empty dict and the deploy dies with a misleading
# "expected map-like data". The .yaml suffix is what makes it read as YAML.
ENVFILE="${ENVFILE:-$HERE/cloudrun.env.yaml}"
CONFIG="$ROOT/vendor_dashboard/image_search_config.json"

if [ ! -f "$ENVFILE" ]; then
  echo "Missing $ENVFILE" >&2
  echo "Create it from cloudrun.env.yaml.example first." >&2
  exit 1
fi

# `gcloud run services update --set-env-vars` replaces the entire environment.
# Refuse to deploy if REQUIRE_AUTH is not explicitly true, so a careless partial
# update can never leave the endpoints open.
if ! grep -qE '^\s*REQUIRE_AUTH:\s*"true"' "$ENVFILE"; then
  echo "REQUIRE_AUTH must be \"true\" in $ENVFILE" >&2
  exit 1
fi

# Tokens are verified against Google's certs for this project id. If it does
# not match the one the app signs users into, the service looks configured but
# rejects every vendor with a 401 and the dashboard reports it as a bad session.
# That mistake cost a round-trip to the vendor already; catch it here instead.
APP_PROJECT="$(sed -n "s/.*projectId:[[:space:]]*'\([^']*\)'.*/\1/p" \
  "$ROOT/vendor_dashboard/lib/firebase_options.dart" | head -1)"
ENV_PROJECT="$(sed -n 's/^FIREBASE_PROJECT_ID:[[:space:]]*"\([^"]*\)".*/\1/p' "$ENVFILE" | head -1)"
if [ -z "$ENV_PROJECT" ]; then
  echo "FIREBASE_PROJECT_ID is missing from $ENVFILE" >&2
  exit 1
fi
if [ -n "$APP_PROJECT" ] && [ "$APP_PROJECT" != "$ENV_PROJECT" ]; then
  echo "Project mismatch: the app signs in to '$APP_PROJECT' but $ENVFILE" >&2
  echo "sets FIREBASE_PROJECT_ID to '$ENV_PROJECT'. Every vendor would get a 401." >&2
  exit 1
fi

# Stage a minimal build context. The repo root holds node_modules, build output
# and media files; uploading all of it would be slow and pointless.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/image_search_service"
cp "$HERE/Dockerfile" "$STAGE/"
cp "$HERE/requirements.txt" "$STAGE/image_search_service/"
cp "$HERE"/*.py "$STAGE/image_search_service/"

echo "==> building $IMAGE"
gcloud builds submit \
  --project "$PROJECT" \
  --tag "$IMAGE" \
  --quiet \
  "$STAGE"

echo "==> deploying to Cloud Run ($REGION)"
gcloud run deploy "$SERVICE" \
  --project "$PROJECT" \
  --region "$REGION" \
  --image "$IMAGE" \
  --platform managed \
  --allow-unauthenticated \
  --memory 2Gi --cpu 1 --timeout 120 --concurrency 2 \
  --min-instances 0 --max-instances 5 \
  --env-vars-file "$ENVFILE" \
  --quiet

URL="$(gcloud run services describe "$SERVICE" \
  --project "$PROJECT" --region "$REGION" \
  --format 'value(status.url)')"

if [ -z "$URL" ]; then
  echo "could not read the service URL" >&2
  exit 1
fi

echo
echo "==> verifying the new revision at $URL/health"
HEALTH="$(curl -sf -m 30 "$URL/health")" || {
  echo "the freshly deployed revision is not healthy" >&2
  exit 1
}
echo "    healthy"

grep -q '"require_auth":true' <<< "$HEALTH" \
  && echo "    require_auth=true confirmed" \
  || { echo "    WARNING: require_auth is not true, check $ENVFILE" >&2; exit 1; }

# The app compiles the production endpoint into itself (see
# `_defaultUrl` in product_image_search_service.dart), so a release build needs
# no flags. This script does not have to hand the URL to the build -- but it does
# keep image_search_config.json correct, and refuses to let the compiled-in
# default drift away from what was just deployed.
#
# The auto-attach bar decides whether a product gets a photo or stays blank, so
# a silently different value in production is the one failure worth refusing a
# deploy over. Read the intent from the env file and insist the running service
# agrees.
WANT_SCORE="$(sed -n 's/^MIN_ACCEPT_SCORE:[[:space:]]*"\?\([0-9.]*\)"\?[[:space:]]*$/\1/p' "$ENVFILE" | tail -1)"
if [ -z "$WANT_SCORE" ]; then
  # Not overridden in the env file, so the bar is whatever config.py defaults
  # to. Read it from there rather than skipping the check, which is what would
  # let the number drift unnoticed.
  WANT_SCORE="$(sed -n 's/^[[:space:]]*MIN_ACCEPT_SCORE = float(_str("MIN_ACCEPT_SCORE", "\([0-9.]*\)").*/\1/p' "$HERE/config.py" | tail -1)"
fi
if [ -n "$WANT_SCORE" ]; then
  GOT_SCORE="$(sed -n 's/.*"min_accept_score":[[:space:]]*\([0-9.]*\).*/\1/p' <<< "$HEALTH" | tail -1)"
  # Compared numerically: the file says 0.60 and the API answers 0.6, which are
  # the same number and different strings.
  if ! awk -v a="$WANT_SCORE" -v b="$GOT_SCORE" 'BEGIN { exit (a == b) ? 0 : 1 }'; then
    echo "threshold drift: want $WANT_SCORE, service is serving ${GOT_SCORE:-nothing}" >&2
    exit 1
  fi
  echo "    min_accept_score=$GOT_SCORE confirmed"
fi

# The app is pointed at a stable Cloud Run domain mapping, not at the default
# <hash>-<region>.a.run.app host, which is what `status.url` reports. Rewriting
# the config with that would swap a durable name for an incidental one on every
# deploy, so an existing config that still answers is left alone.
APP_URL=""
if [ -f "$CONFIG" ]; then
  APP_URL="$(sed -n 's/.*"IMAGE_SEARCH_URL"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" | tail -1)"
fi

if [ -n "$APP_URL" ] && curl -sf -m 15 "$APP_URL/health" > /dev/null; then
  echo "    app config already points at $APP_URL (alive, kept)"
else
  printf '{\n  "IMAGE_SEARCH_URL": "%s"\n}\n' "$URL" > "$CONFIG"
  echo "    app config set to $URL"
  APP_URL="$URL"
fi

# The Dart source holds the same URL as its compiled-in default. A release build
# with no --dart-define uses that value, so if the two disagree the app silently
# talks to a different service than the one just deployed -- the exact failure
# that made image lookups stop working with no error anywhere. Refuse rather
# than warn.
APP_DART="$ROOT/vendor_dashboard/lib/services/product_image_search_service.dart"
# The URL is usually wrapped onto its own line by the formatter, so join the
# file into one stream before matching rather than assuming a single line.
COMPILED_URL="$(tr '\n' ' ' < "$APP_DART" \
  | grep -o "_defaultUrl =[[:space:]]*'[^']*'" \
  | head -1 | sed "s/.*'\([^']*\)'.*/\1/")"
if [ -z "$COMPILED_URL" ]; then
  echo "could not read _defaultUrl from $APP_DART" >&2
  exit 1
fi
if [ "$COMPILED_URL" != "$APP_URL" ]; then
  cat >&2 <<EOF
app/service URL mismatch

  deployed to : $APP_URL
  compiled in : $COMPILED_URL

A release build with no --dart-define would call $COMPILED_URL, not the service
just deployed. Edit _defaultUrl in $APP_DART to match, then deploy again.
EOF
  exit 1
fi
echo "    compiled-in app default matches ($COMPILED_URL)"

echo
echo "  live url : $URL"
echo "  app url  : $APP_URL"
echo "  app build: flutter build apk --release   (no flags needed)"
