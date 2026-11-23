#!/usr/bin/env bash
# Upload GitHub Release assets sequentially with live progress, slow-link hardening, partial-asset cleanup, and automatic retries
# Usage: ./gh-release-upload-resilient.sh --repo OWNER/REPO --tag TAG [options] FILE [FILE...]

set -euo pipefail

# --- Dependency checks ---
for dep in gh curl python3; do
  command -v "$dep" >/dev/null 2>&1 || { echo "Error: '$dep' is required." >&2; exit 1; }
done

# --- Defaults (configurable via env or flags) ---
REPO="${GH_REPO:-}"
TAG="${GH_TAG:-}"
CLOBBER=0
RETRIES="${RETRIES:-5}"
RETRY_DELAY="${RETRY_DELAY:-15}"
SPEED_LIMIT="${SPEED_LIMIT:-1024}"     # bytes/sec minimum before considering socket stalled
SPEED_TIME="${SPEED_TIME:-120}"        # seconds below SPEED_LIMIT before aborting stalled socket
HTTP_VERSION="${HTTP_VERSION:-1.1}"    # 1.1 or 2
STATUS_FILE="${STATUS_FILE:-}"
DRY_RUN=0
FILES=()

usage() {
  cat <<'EOF'
Upload GitHub Release assets sequentially with slow-link hardening and retries.

Usage:
  gh-release-upload-resilient.sh --repo OWNER/REPO --tag TAG [options] FILE [FILE...]

Options:
  --repo OWNER/REPO    Target GitHub repository (or set GH_REPO)
  --tag TAG            Target release tag (or set GH_TAG)
  --clobber            Overwrite existing uploaded assets with the same name
  --retries N          Max attempts per file (default: 5)
  --retry-delay SEC    Base retry delay in seconds (default: 15)
  --speed-limit BYTES  Min average bytes/sec over --speed-time (default: 1024)
  --speed-time SEC     Seconds of stalled transfer before aborting socket (default: 120)
  --http2              Use HTTP/2 instead of HTTP/1.1 (default: HTTP/1.1)
  --status-file PATH   Write machine-readable status updates to PATH
  --dry-run            Validate inputs and show planned actions without uploading
  -h, --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)        REPO="${2:?Missing value for --repo}"; shift 2 ;;
    --tag)         TAG="${2:?Missing value for --tag}"; shift 2 ;;
    --clobber)     CLOBBER=1; shift ;;
    --retries)     RETRIES="${2:?Missing value for --retries}"; shift 2 ;;
    --retry-delay) RETRY_DELAY="${2:?Missing value for --retry-delay}"; shift 2 ;;
    --speed-limit) SPEED_LIMIT="${2:?Missing value for --speed-limit}"; shift 2 ;;
    --speed-time)  SPEED_TIME="${2:?Missing value for --speed-time}"; shift 2 ;;
    --http2)       HTTP_VERSION="2"; shift ;;
    --status-file) STATUS_FILE="${2:?Missing value for --status-file}"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    --)            shift; FILES+=("$@"); break ;;
    -*)            echo "Error: Unknown option '$1'" >&2; usage >&2; exit 1 ;;
    *)             FILES+=("$1"); shift ;;
  esac
done

if [[ -z "$REPO" || -z "$TAG" || ${#FILES[@]} -eq 0 ]]; then
  echo "Error: --repo, --tag, and at least one FILE are required." >&2
  usage >&2
  exit 1
fi

for f in "${FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "Error: File not found: $f" >&2
    exit 1
  fi
done

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

write_status() {
  local state="$1" file="$2" attempt="$3" detail="$4"
  [[ -z "$STATUS_FILE" ]] && return 0
  python3 - "$STATUS_FILE" "$state" "$REPO" "$TAG" "$file" "$attempt" "$RETRIES" "$detail" <<'PY'
import json, sys, time
path, state, repo, tag, filename, attempt, max_retries, detail = sys.argv[1:9]
payload = {
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "state": state,
    "repo": repo,
    "tag": tag,
    "file": filename,
    "attempt": int(attempt),
    "max_retries": int(max_retries),
    "detail": detail,
}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2)
PY
}

file_size_bytes() {
  python3 -c 'import os, sys; print(os.path.getsize(sys.argv[1]))' "$1"
}

url_encode() {
  python3 -c 'import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

# Verify gh authentication and fetch token
gh auth status >/dev/null 2>&1 || { echo "Error: gh CLI is not authenticated. Run 'gh auth login'." >&2; exit 1; }
GH_TOKEN="$(gh auth token)"

# Fetch release metadata
log "Fetching release '$TAG' from '$REPO'..."
RELEASE_JSON="$(gh api "repos/${REPO}/releases/tags/${TAG}")"
RELEASE_ID="$(python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])' <<<"$RELEASE_JSON")"
UPLOAD_BASE="https://uploads.github.com/repos/${REPO}/releases/${RELEASE_ID}/assets"
log "Release ID: ${RELEASE_ID}"

get_remote_asset_info() {
  local name="$1"
  gh api "repos/${REPO}/releases/${RELEASE_ID}/assets?per_page=100" | python3 -c '
import json, sys
target = sys.argv[1]
assets = json.load(sys.stdin)
for a in assets:
    if a.get("name") == target:
        aid = a["id"]
        st = a.get("state", "")
        sz = a.get("size", 0)
        print(f"{aid}|{st}|{sz}")
        sys.exit(0)
print("")
' "$name"
}

delete_remote_asset() {
  local asset_id="$1" reason="$2"
  log "Deleting remote asset id=${asset_id} (${reason})..."
  gh api -X DELETE "repos/${REPO}/releases/assets/${asset_id}" >/dev/null
}

HTTP_FLAG="--http1.1"
if [[ "$HTTP_VERSION" == "2" ]]; then
  HTTP_FLAG="--http2"
fi

TMP_RESP="$(mktemp)"
trap 'rm -f "$TMP_RESP"' EXIT

for FILE_PATH in "${FILES[@]}"; do
  FILE_NAME="$(basename "$FILE_PATH")"
  LOCAL_SIZE="$(file_size_bytes "$FILE_PATH")"
  ENCODED_NAME="$(url_encode "$FILE_NAME")"
  UPLOAD_URL="${UPLOAD_BASE}?name=${ENCODED_NAME}"

  log "=== Preparing: ${FILE_NAME} (${LOCAL_SIZE} bytes) ==="

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] Would upload '${FILE_PATH}' -> '${UPLOAD_URL}' (${HTTP_FLAG}, speed-limit=${SPEED_LIMIT}B/s over ${SPEED_TIME}s)"
    continue
  fi

  UPLOADED=0
  for (( ATTEMPT=1; ATTEMPT<=RETRIES; ATTEMPT++ )); do
    EXISTING="$(get_remote_asset_info "$FILE_NAME")"
    if [[ -n "$EXISTING" ]]; then
      IFS='|' read -r ASSET_ID ASSET_STATE ASSET_SIZE <<<"$EXISTING"
      if [[ "$ASSET_STATE" == "uploaded" && "$ASSET_SIZE" == "$LOCAL_SIZE" && "$CLOBBER" -eq 0 ]]; then
        log "Asset '${FILE_NAME}' is already uploaded with matching size (${LOCAL_SIZE} bytes). Skipping."
        write_status "skipped_already_uploaded" "$FILE_NAME" "$ATTEMPT" "Already uploaded (${LOCAL_SIZE} bytes)"
        UPLOADED=1
        break
      elif [[ "$ASSET_STATE" != "uploaded" ]]; then
        delete_remote_asset "$ASSET_ID" "incomplete state='${ASSET_STATE}'"
      elif [[ "$CLOBBER" -eq 1 ]]; then
        delete_remote_asset "$ASSET_ID" "--clobber requested"
      else
        delete_remote_asset "$ASSET_ID" "size mismatch remote=${ASSET_SIZE} local=${LOCAL_SIZE}"
      fi
    fi

    log "Attempt ${ATTEMPT}/${RETRIES}: uploading '${FILE_NAME}' via ${HTTP_FLAG}..."
    write_status "uploading" "$FILE_NAME" "$ATTEMPT" "Uploading ${LOCAL_SIZE} bytes"

    # Pass Authorization header via stdin (-K -) so token never appears in process args
    set +e
    HTTP_CODE="$(
      printf 'header = "Authorization: Bearer %s"\n' "$GH_TOKEN" | \
      curl -K - \
        "$HTTP_FLAG" \
        --fail-with-body \
        --connect-timeout 30 \
        --max-time 0 \
        --keepalive-time 30 \
        --speed-limit "$SPEED_LIMIT" \
        --speed-time "$SPEED_TIME" \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@${FILE_PATH}" \
        -o "$TMP_RESP" \
        -w "%{http_code}" \
        "$UPLOAD_URL"
    )"
    CURL_RC=$?
    set -e

    if [[ "$CURL_RC" -eq 0 && "$HTTP_CODE" == "201" ]]; then
      # Verify on GitHub that the asset is in 'uploaded' state with exact byte size
      VERIFY="$(get_remote_asset_info "$FILE_NAME")"
      IFS='|' read -r V_ID V_STATE V_SIZE <<<"$VERIFY"
      if [[ "$V_STATE" == "uploaded" && "$V_SIZE" == "$LOCAL_SIZE" ]]; then
        log "SUCCESS: '${FILE_NAME}' uploaded and verified (asset_id=${V_ID}, size=${V_SIZE} bytes)."
        write_status "completed" "$FILE_NAME" "$ATTEMPT" "Verified asset_id=${V_ID}, size=${V_SIZE}"
        UPLOADED=1
        break
      else
        log "WARNING: HTTP 201 received, but verification failed (state='${V_STATE}', size='${V_SIZE}' vs local '${LOCAL_SIZE}')."
        write_status "verify_failed" "$FILE_NAME" "$ATTEMPT" "state=${V_STATE} size=${V_SIZE}"
      fi
    else
      ERR_SNIPPET="$(head -c 300 "$TMP_RESP" 2>/dev/null | tr '\n' ' ' || true)"
      log "ERROR: Attempt ${ATTEMPT}/${RETRIES} failed (curl_rc=${CURL_RC}, http_code=${HTTP_CODE:-none}). ${ERR_SNIPPET}"
      write_status "attempt_failed" "$FILE_NAME" "$ATTEMPT" "curl_rc=${CURL_RC} http_code=${HTTP_CODE:-none}"
    fi

    if (( ATTEMPT < RETRIES )); then
      SLEEP_SEC=$(( RETRY_DELAY * ATTEMPT ))
      log "Waiting ${SLEEP_SEC}s before retry..."
      sleep "$SLEEP_SEC"
    fi
  done

  if [[ "$UPLOADED" -ne 1 ]]; then
    log "FATAL: Failed to upload '${FILE_NAME}' after ${RETRIES} attempts."
    write_status "failed" "$FILE_NAME" "$RETRIES" "Exhausted all retries"
    exit 1
  fi
done

log "All files uploaded and verified successfully."
