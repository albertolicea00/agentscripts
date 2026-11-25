#!/usr/bin/env bash
# Upload a large GitHub Release asset over a slow/unstable connection by streaming resumable chunks to Google Colab via SSH/rsync with persistent GitHub Draft Release checkpointing, reassembling & verifying SHA-256 on Colab, and uploading to GitHub from Colab's network
# Usage: ./colab-gh-release-upload.sh --repo OWNER/REPO --tag TAG [options] FILE

set -euo pipefail

# --- Dependency checks ---
for dep in gh ssh rsync python3; do
  command -v "$dep" >/dev/null 2>&1 || { echo "Error: '$dep' is required." >&2; exit 1; }
done

COLAB_BIN="${COLAB_BIN:-$(command -v colab 2>/dev/null || echo "$HOME/.local/bin/colab")}"
if [[ ! -x "$COLAB_BIN" ]]; then
  echo "Error: 'colab' CLI not found. Install google-colab-cli or set COLAB_BIN." >&2
  exit 1
fi

# --- Defaults ---
REPO="${GH_REPO:-}"
TAG="${GH_TAG:-}"
CHUNK_MB="${CHUNK_MB:-10}"
PARTS_DIR=""
SESSION="${COLAB_SESSION:-colab}"
SSH_HOST="${COLAB_SSH_HOST:-colab}"
CLOBBER=0
RETRIES="${RETRIES:-20}"
RETRY_DELAY="${RETRY_DELAY:-15}"
KEEP_SESSION=0
STATUS_FILE="${STATUS_FILE:-}"
FILE_PATH=""

usage() {
  cat <<'EOF'
Resumable GitHub Release uploader via Google Colab CLI SSH with persistent checkpointing.

Splits a large local file into small chunks, transfers each chunk to a Colab VM
with resumable rsync (--partial --inplace) and per-chunk SHA-256 verification,
checkpoints each verified chunk immediately from Colab to a hidden temporary
GitHub Draft Release (so progress survives Colab VM resets or restarts), then
reassembles, verifies full SHA-256 on Colab, uploads directly from Colab's
datacenter network to the target GitHub Release, and cleans up the staging draft.

Usage:
  colab-gh-release-upload.sh --repo OWNER/REPO --tag TAG [options] FILE

Options:
  --repo OWNER/REPO    Target GitHub repository (or set GH_REPO)
  --tag TAG            Target release tag (or set GH_TAG)
  --chunk-mb N         Chunk size in MiB when splitting locally (default: 10)
  --parts-dir DIR      Reuse an existing directory containing *.part* and SHA256SUMS.txt
  -s, --session NAME   Colab CLI session name (default: colab or $COLAB_SESSION)
  --ssh-host HOST      SSH host alias for Colab (default: colab or $COLAB_SSH_HOST)
  --clobber            Overwrite existing uploaded asset with the same name
  --retries N          Max rsync retries per chunk (default: 20)
  --retry-delay SEC    Delay in seconds between retries (default: 15)
  --keep-session       Keep the Colab session running after upload finishes
  --status-file PATH   Write machine-readable JSON status updates to PATH
  -h, --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)        REPO="${2:?Missing value for --repo}"; shift 2 ;;
    --tag)         TAG="${2:?Missing value for --tag}"; shift 2 ;;
    --chunk-mb)    CHUNK_MB="${2:?Missing value for --chunk-mb}"; shift 2 ;;
    --parts-dir)   PARTS_DIR="${2:?Missing value for --parts-dir}"; shift 2 ;;
    -s|--session)  SESSION="${2:?Missing value for --session}"; shift 2 ;;
    --ssh-host)    SSH_HOST="${2:?Missing value for --ssh-host}"; shift 2 ;;
    --clobber)     CLOBBER=1; shift ;;
    --retries)     RETRIES="${2:?Missing value for --retries}"; shift 2 ;;
    --retry-delay) RETRY_DELAY="${2:?Missing value for --retry-delay}"; shift 2 ;;
    --keep-session) KEEP_SESSION=1; shift ;;
    --status-file) STATUS_FILE="${2:?Missing value for --status-file}"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    -*)            echo "Error: Unknown option '$1'" >&2; usage >&2; exit 1 ;;
    *)
      if [[ -z "$FILE_PATH" ]]; then
        FILE_PATH="$1"
      else
        echo "Error: Unexpected argument '$1'" >&2; usage >&2; exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$REPO" || -z "$TAG" || -z "$FILE_PATH" ]]; then
  echo "Error: --repo, --tag, and FILE are required." >&2
  usage >&2
  exit 1
fi

if [[ ! -f "$FILE_PATH" ]]; then
  echo "Error: File not found: $FILE_PATH" >&2
  exit 1
fi

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

write_status() {
  local phase="$1" current="$2" total="$3" detail="$4"
  [[ -z "$STATUS_FILE" ]] && return 0
  python3 - "$STATUS_FILE" "$phase" "$REPO" "$TAG" "$FILE_NAME" "$current" "$total" "$detail" <<'PY'
import json, sys, time
path, phase, repo, tag, filename, cur, tot, detail = sys.argv[1:9]
payload = {
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "phase": phase,
    "repo": repo,
    "tag": tag,
    "file": filename,
    "part_current": int(cur),
    "part_total": int(tot),
    "detail": detail,
}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2)
PY
}

FILE_NAME="$(basename "$FILE_PATH")"
LOCAL_SIZE="$(python3 -c 'import os, sys; print(os.path.getsize(sys.argv[1]))' "$FILE_PATH")"
ENCODED_NAME="$(python3 -c 'import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$FILE_NAME")"
STAGING_NAME="staging-upload:${TAG}:${FILE_NAME}"
STAGING_TAG="_staging-$(python3 -c 'import hashlib, sys; print(hashlib.sha256(sys.argv[1].encode()).hexdigest()[:12])' "$STAGING_NAME")"

# --- Verify GitHub auth & target release ---
gh auth status >/dev/null 2>&1 || { echo "Error: gh CLI is not authenticated." >&2; exit 1; }
GH_TOKEN="$(gh auth token)"

log "Fetching release '$TAG' from '$REPO'..."
RELEASE_ID="$(gh api "repos/${REPO}/releases/tags/${TAG}" --jq '.id')"
log "Release ID: ${RELEASE_ID}"

get_release_asset_info() {
  local rel_id="$1" target_name="$2" raw
  raw="$(gh api "repos/${REPO}/releases/${rel_id}/assets?per_page=100" 2>/dev/null)" || return 1
  [[ -n "$raw" ]] || return 1
  python3 -c '
import json, sys
target = sys.argv[1]
for a in json.load(sys.stdin):
    if a.get("name") == target:
        aid = a["id"]
        st = a.get("state", "")
        sz = a.get("size", 0)
        print(f"{aid}|{st}|{sz}")
        sys.exit(0)
print("")
' "$target_name" <<<"$raw"
}

get_or_create_staging_release() {
  local raw existing_id
  raw="$(gh api "repos/${REPO}/releases?per_page=100" 2>/dev/null)" || return 1
  existing_id="$(python3 -c '
import json, sys
target_name = sys.argv[1]
for r in json.load(sys.stdin):
    if r.get("draft") and r.get("name") == target_name:
        print(r["id"])
        sys.exit(0)
print("")
' "$STAGING_NAME" <<<"$raw")"
  if [[ -n "$existing_id" ]]; then
    echo "$existing_id"
    return 0
  fi
  gh api -X POST "repos/${REPO}/releases" \
    -f tag_name="$STAGING_TAG" \
    -f name="$STAGING_NAME" \
    -f body="Temporary resumable upload staging for ${FILE_NAME} (${TAG}). Safe to delete after upload completes." \
    -F draft=true \
    --jq '.id'
}

EXISTING="$(get_release_asset_info "$RELEASE_ID" "$FILE_NAME" || true)"
if [[ -n "$EXISTING" ]]; then
  IFS='|' read -r ASSET_ID ASSET_STATE ASSET_SIZE <<<"$EXISTING"
  if [[ "$ASSET_STATE" == "uploaded" && "$ASSET_SIZE" == "$LOCAL_SIZE" && "$CLOBBER" -eq 0 ]]; then
    log "Asset '${FILE_NAME}' is already uploaded with matching size (${LOCAL_SIZE} bytes). Nothing to do."
    write_status "completed" 0 0 "Already uploaded (${LOCAL_SIZE} bytes)"
    exit 0
  fi
fi

# --- Prepare local parts ---
CLEANUP_PARTS=0
if [[ -z "$PARTS_DIR" ]]; then
  PARTS_DIR="$(mktemp -d)"
  CLEANUP_PARTS=1
  trap '[[ "$CLEANUP_PARTS" -eq 1 ]] && rm -rf "$PARTS_DIR"' EXIT
  log "Splitting '${FILE_NAME}' (${LOCAL_SIZE} bytes) into ${CHUNK_MB} MiB chunks in '${PARTS_DIR}'..."
  python3 - "$FILE_PATH" "$PARTS_DIR" "$CHUNK_MB" <<'PY'
import hashlib, os, sys
src, out_dir, chunk_mb = sys.argv[1], sys.argv[2], int(sys.argv[3])
base = os.path.basename(src)
chunk_size = chunk_mb * 1024 * 1024
full_hash = hashlib.sha256()
parts = []
idx = 1
with open(src, "rb") as f:
    while True:
        data = f.read(chunk_size)
        if not data:
            break
        full_hash.update(data)
        name = f"{base}.part{idx:02d}"
        with open(os.path.join(out_dir, name), "wb") as pf:
            pf.write(data)
        parts.append((hashlib.sha256(data).hexdigest(), name))
        idx += 1
with open(os.path.join(out_dir, "SHA256SUMS.txt"), "w", encoding="utf-8") as sf:
    sf.write(f"{full_hash.hexdigest()}  {base}\n")
    for h, name in parts:
        sf.write(f"{h}  {name}\n")
print(f"Created {len(parts)} parts, full SHA-256={full_hash.hexdigest()}")
PY
else
  if [[ ! -f "${PARTS_DIR}/SHA256SUMS.txt" ]]; then
    echo "Error: --parts-dir '${PARTS_DIR}' does not contain SHA256SUMS.txt" >&2
    exit 1
  fi
  log "Reusing existing parts in '${PARTS_DIR}'."
fi

PART_FILES=()
while IFS= read -r p; do
  PART_FILES+=("$p")
done < <(find "$PARTS_DIR" -maxdepth 1 -type f -name "${FILE_NAME}.part*" | sort)

TOTAL_PARTS="${#PART_FILES[@]}"
if [[ "$TOTAL_PARTS" -eq 0 ]]; then
  echo "Error: No part files matching '${FILE_NAME}.part*' found in '${PARTS_DIR}'." >&2
  exit 1
fi
log "Total parts to sync: ${TOTAL_PARTS}"

# --- Persistent GitHub Draft Release for chunk checkpointing ---
STAGING_RELEASE_ID="$(get_or_create_staging_release)"
log "Using persistent GitHub staging draft release ID: ${STAGING_RELEASE_ID} ('${STAGING_NAME}')"

# --- Colab SSH helpers ---
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o ConnectTimeout=30)
SSH_CMD="ssh ${SSH_OPTS[*]}"
REMOTE_DIR="/content/gh-upload-staging/${FILE_NAME}.d"

ensure_colab_session() {
  if ! "$COLAB_BIN" sessions 2>/dev/null | grep -qE "\\b${SESSION}\\b"; then
    log "Creating Colab session '${SESSION}'..."
    "$COLAB_BIN" new -s "$SESSION"
    return 10
  fi
  return 0
}

prepare_colab_vm() {
  local rc=0
  ensure_colab_session || rc=$?
  if [[ "$rc" -ne 0 && "$rc" -ne 10 ]]; then
    return "$rc"
  fi
  log "Preparing Colab staging directory '${REMOTE_DIR}' and ensuring rsync is installed..."
  ssh "${SSH_OPTS[@]}" "$SSH_HOST" "mkdir -p '${REMOTE_DIR}' && (command -v rsync >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq rsync >/dev/null))"
  sleep 2
  log "Uploading SHA256SUMS.txt to Colab..."
  for (( attempt=1; attempt<=RETRIES; attempt++ )); do
    if rsync -e "$SSH_CMD" --partial --inplace --timeout=60 "${PARTS_DIR}/SHA256SUMS.txt" "${SSH_HOST}:${REMOTE_DIR}/SHA256SUMS.txt"; then
      sleep 2
      return 0
    fi
    log "WARNING: Failed to upload SHA256SUMS.txt (attempt ${attempt}/${RETRIES}); retrying in ${RETRY_DELAY}s..."
    sleep "$RETRY_DELAY"
    ensure_colab_session || true
    ssh "${SSH_OPTS[@]}" "$SSH_HOST" "mkdir -p '${REMOTE_DIR}'" || true
    sleep 2
  done
  return 1
}

checkpoint_part_from_colab() {
  local part_name="$1"
  local encoded_part
  encoded_part="$(python3 -c 'import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$part_name")"

  # Delete any stale/partial staging asset with the same name first
  local existing_stage
  existing_stage="$(get_release_asset_info "$STAGING_RELEASE_ID" "$part_name" || true)"
  if [[ -n "$existing_stage" ]]; then
    IFS='|' read -r s_id s_state s_size <<<"$existing_stage"
    gh api -X DELETE "repos/${REPO}/releases/assets/${s_id}" >/dev/null 2>&1 || true
  fi

  local stage_upload_url="https://uploads.github.com/repos/${REPO}/releases/${STAGING_RELEASE_ID}/assets?name=${encoded_part}"
  local cp_script='
set -euo pipefail
REMOTE_FILE="$1"
UPLOAD_URL="$2"
CURL_CFG="$(mktemp)"
RESP_FILE="$(mktemp)"
trap '\''rm -f "$CURL_CFG" "$RESP_FILE"'\'' EXIT
chmod 600 "$CURL_CFG"
cat > "$CURL_CFG"
HTTP_CODE="$(curl -K "$CURL_CFG" \
  --fail-with-body \
  --connect-timeout 30 \
  --max-time 180 \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@${REMOTE_FILE}" \
  -o "$RESP_FILE" \
  -w "%{http_code}" \
  "$UPLOAD_URL")"
if [[ "$HTTP_CODE" != "201" ]]; then
  head -c 300 "$RESP_FILE" >&2 || true
  exit 1
fi
'
  local cp_attempt
  for (( cp_attempt=1; cp_attempt<=5; cp_attempt++ )); do
    if printf 'header = "Authorization: Bearer %s"\n' "$GH_TOKEN" | \
      ssh "${SSH_OPTS[@]}" "$SSH_HOST" bash -c "$(printf '%q' "$cp_script")" _ "${REMOTE_DIR}/${part_name}" "$stage_upload_url"; then
      sleep 1
      return 0
    fi
    log "WARNING: Checkpoint upload to GitHub staging failed for '${part_name}' (attempt ${cp_attempt}/5). Retrying in 5s..."
    sleep 5
  done
  return 1
}

write_status "preparing_colab" 0 "$TOTAL_PARTS" "Checking rsync and staging dir on Colab"
prepare_colab_vm

# --- Sequentially upload each part with resumable rsync + SHA-256 + persistent GitHub checkpoint ---
PART_IDX=0
for PART_PATH in "${PART_FILES[@]}"; do
  PART_IDX=$(( PART_IDX + 1 ))
  PART_NAME="$(basename "$PART_PATH")"
  LOCAL_PART_SIZE="$(python3 -c 'import os, sys; print(os.path.getsize(sys.argv[1]))' "$PART_PATH")"
  EXPECTED_SHA="$(awk -v n="$PART_NAME" '$2==n {print $1; exit}' "${PARTS_DIR}/SHA256SUMS.txt")"

  # 1) Check persistent GitHub staging draft first (survives Colab VM resets & restarts)
  STAGE_INFO="$(get_release_asset_info "$STAGING_RELEASE_ID" "$PART_NAME" || true)"
  if [[ -n "$STAGE_INFO" ]]; then
    IFS='|' read -r S_ID S_STATE S_SIZE <<<"$STAGE_INFO"
    if [[ "$S_STATE" == "uploaded" && "$S_SIZE" == "$LOCAL_PART_SIZE" ]]; then
      log "[${PART_IDX}/${TOTAL_PARTS}] '${PART_NAME}' already checkpointed in GitHub staging draft (${S_SIZE} bytes). Skipping."
      write_status "part_verified" "$PART_IDX" "$TOTAL_PARTS" "Already checkpointed ${PART_NAME}"
      continue
    fi
  fi

  # 2) Check if already verified on current Colab VM (just needs checkpointing)
  REMOTE_SHA="$(ssh "${SSH_OPTS[@]}" "$SSH_HOST" "if [ -f '${REMOTE_DIR}/${PART_NAME}' ]; then sha256sum '${REMOTE_DIR}/${PART_NAME}' | awk '{print \$1}'; fi" 2>/dev/null || true)"
  sleep 1
  if [[ -n "$EXPECTED_SHA" && "$REMOTE_SHA" == "$EXPECTED_SHA" ]]; then
    log "[${PART_IDX}/${TOTAL_PARTS}] '${PART_NAME}' already verified on Colab; checkpointing to GitHub staging draft..."
    checkpoint_part_from_colab "$PART_NAME"
    log "[${PART_IDX}/${TOTAL_PARTS}] Checkpointed '${PART_NAME}' to GitHub staging draft."
    write_status "part_verified" "$PART_IDX" "$TOTAL_PARTS" "Checkpointed ${PART_NAME}"
    continue
  fi

  # 3) Stream chunk via resumable rsync to Colab
  SYNCED=0
  for (( attempt=1; attempt<=RETRIES; attempt++ )); do
    log "[${PART_IDX}/${TOTAL_PARTS}] Syncing '${PART_NAME}' (attempt ${attempt}/${RETRIES})..."
    write_status "syncing_parts" "$PART_IDX" "$TOTAL_PARTS" "Uploading ${PART_NAME} (attempt ${attempt}/${RETRIES})"

    set +e
    rsync -e "$SSH_CMD" --partial --inplace --progress --timeout=60 "$PART_PATH" "${SSH_HOST}:${REMOTE_DIR}/${PART_NAME}"
    RC=$?
    set -e
    sleep 2

    if [[ "$RC" -eq 0 ]]; then
      REMOTE_SHA="$(ssh "${SSH_OPTS[@]}" "$SSH_HOST" "sha256sum '${REMOTE_DIR}/${PART_NAME}' | awk '{print \$1}'" 2>/dev/null || true)"
      sleep 1
      if [[ -z "$EXPECTED_SHA" || "$REMOTE_SHA" == "$EXPECTED_SHA" ]]; then
        log "[${PART_IDX}/${TOTAL_PARTS}] Verified '${PART_NAME}' on Colab (sha256=${REMOTE_SHA:0:12}...). Checkpointing to GitHub staging draft..."
        if checkpoint_part_from_colab "$PART_NAME"; then
          log "[${PART_IDX}/${TOTAL_PARTS}] Checkpointed '${PART_NAME}' to GitHub staging draft."
          write_status "part_verified" "$PART_IDX" "$TOTAL_PARTS" "Verified & checkpointed ${PART_NAME}"
          SYNCED=1
          break
        else
          log "WARNING: Failed to checkpoint '${PART_NAME}' to GitHub staging draft. Retrying..."
        fi
      else
        log "WARNING: SHA-256 mismatch on Colab for '${PART_NAME}' (got '${REMOTE_SHA}', expected '${EXPECTED_SHA}'). Retrying..."
      fi
    else
      log "WARNING: rsync exited with code ${RC} for '${PART_NAME}' (attempt ${attempt}/${RETRIES}). Waiting ${RETRY_DELAY}s..."
      sleep "$RETRY_DELAY"
      SESSION_RC=0
      ensure_colab_session || SESSION_RC=$?
      if [[ "$SESSION_RC" -eq 10 || "$RC" -eq 3 ]]; then
        log "Colab VM was recreated or staging dir missing; re-initializing staging directory on Colab..."
        prepare_colab_vm
      fi
    fi
  done

  if [[ "$SYNCED" -ne 1 ]]; then
    log "FATAL: Failed to sync '${PART_NAME}' after ${RETRIES} attempts."
    write_status "failed" "$PART_IDX" "$TOTAL_PARTS" "Failed syncing ${PART_NAME}"
    exit 1
  fi
done

# --- Build staging manifest for any parts that need to be fetched back onto Colab ---
STAGING_MANIFEST="$(gh api "repos/${REPO}/releases/${STAGING_RELEASE_ID}/assets?per_page=100" | python3 -c '
import json, sys
prefix = sys.argv[1] + ".part"
assets = [a for a in json.load(sys.stdin) if a.get("state") == "uploaded" and a.get("name", "").startswith(prefix)]
assets.sort(key=lambda a: a["name"])
for a in assets:
    print(f"{a[\"name\"]}|{a[\"id\"]}|{a[\"size\"]}")
' "$FILE_NAME")"

# --- Clean any partial/existing asset on target GitHub release before Colab uploads ---
EXISTING="$(get_release_asset_info "$RELEASE_ID" "$FILE_NAME" || true)"
if [[ -n "$EXISTING" ]]; then
  IFS='|' read -r ASSET_ID ASSET_STATE ASSET_SIZE <<<"$EXISTING"
  if [[ "$ASSET_STATE" != "uploaded" || "$CLOBBER" -eq 1 || "$ASSET_SIZE" != "$LOCAL_SIZE" ]]; then
    log "Deleting existing remote asset id=${ASSET_ID} (state='${ASSET_STATE}', size=${ASSET_SIZE})..."
    gh api -X DELETE "repos/${REPO}/releases/assets/${ASSET_ID}" >/dev/null
  fi
fi

# --- Fetch any missing checkpointed parts onto Colab, reassemble, verify SHA-256, and upload to target Release ---
UPLOAD_URL="https://uploads.github.com/repos/${REPO}/releases/${RELEASE_ID}/assets?name=${ENCODED_NAME}"
log "Ensuring all parts on Colab, reassembling '${FILE_NAME}', verifying full SHA-256, and uploading to GitHub Release..."
write_status "uploading_from_colab" "$TOTAL_PARTS" "$TOTAL_PARTS" "Fetching checkpoints, reassembling, and uploading from Colab to GitHub"

REMOTE_SCRIPT='
set -euo pipefail
REMOTE_DIR="$1"
FILE_NAME="$2"
UPLOAD_URL="$3"
REPO="$4"
MANIFEST="$5"
CURL_CFG="$(mktemp)"
RESP_FILE="$(mktemp)"
trap '\''rm -f "$CURL_CFG" "$RESP_FILE"'\'' EXIT
chmod 600 "$CURL_CFG"
cat > "$CURL_CFG"

mkdir -p "$REMOTE_DIR"
cd "$REMOTE_DIR"

while IFS="|" read -r part_name asset_id expected_size; do
  [[ -z "$part_name" ]] && continue
  need_dl=0
  if [[ ! -f "$part_name" ]]; then
    need_dl=1
  else
    cur_size="$(stat -c%s "$part_name" 2>/dev/null || echo 0)"
    if [[ "$cur_size" != "$expected_size" ]]; then
      need_dl=1
    fi
  fi
  if [[ "$need_dl" -eq 1 ]]; then
    echo "[Colab] Fetching checkpointed ${part_name} from GitHub staging..."
    curl -K "$CURL_CFG" \
      --fail \
      --location \
      --connect-timeout 30 \
      --max-time 300 \
      -H "Accept: application/octet-stream" \
      -o "$part_name" \
      "https://api.github.com/repos/${REPO}/releases/assets/${asset_id}"
  fi
done <<<"$MANIFEST"

echo "[Colab] Verifying all chunk SHA-256 checksums..."
grep "${FILE_NAME}\.part" SHA256SUMS.txt | sha256sum -c -

echo "[Colab] Reassembling ${FILE_NAME}..."
cat "${FILE_NAME}".part* > "${FILE_NAME}"

echo "[Colab] Verifying full SHA-256..."
grep "  ${FILE_NAME}$" SHA256SUMS.txt | sha256sum -c -

echo "[Colab] Uploading ${FILE_NAME} to GitHub Release..."
HTTP_CODE="$(curl -K "$CURL_CFG" \
  --fail-with-body \
  --connect-timeout 30 \
  --max-time 600 \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@${FILE_NAME}" \
  -o "$RESP_FILE" \
  -w "%{http_code}" \
  "$UPLOAD_URL")"

echo "[Colab] GitHub upload finished with HTTP ${HTTP_CODE}."
if [[ "$HTTP_CODE" != "201" ]]; then
  head -c 400 "$RESP_FILE" >&2 || true
  exit 1
fi

echo "[Colab] Cleaning up remote staging directory..."
rm -rf "$REMOTE_DIR"
'

printf 'header = "Authorization: Bearer %s"\n' "$GH_TOKEN" | \
  ssh "${SSH_OPTS[@]}" "$SSH_HOST" bash -c "$(printf '%q' "$REMOTE_SCRIPT")" _ "$REMOTE_DIR" "$FILE_NAME" "$UPLOAD_URL" "$REPO" "$STAGING_MANIFEST"

# --- Final verification on GitHub ---
VERIFY="$(get_release_asset_info "$RELEASE_ID" "$FILE_NAME" || true)"
IFS='|' read -r V_ID V_STATE V_SIZE <<<"$VERIFY"
if [[ "$V_STATE" == "uploaded" && "$V_SIZE" == "$LOCAL_SIZE" ]]; then
  log "SUCCESS: '${FILE_NAME}' uploaded via Colab and verified on GitHub (asset_id=${V_ID}, size=${V_SIZE} bytes)."
  write_status "completed" "$TOTAL_PARTS" "$TOTAL_PARTS" "Verified asset_id=${V_ID}, size=${V_SIZE}"
else
  log "ERROR: Verification on GitHub failed (state='${V_STATE}', size='${V_SIZE}' vs local '${LOCAL_SIZE}')."
  write_status "verify_failed" "$TOTAL_PARTS" "$TOTAL_PARTS" "state=${V_STATE} size=${V_SIZE}"
  exit 1
fi

# --- Clean up temporary staging draft release ---
log "Deleting temporary GitHub staging draft release ID ${STAGING_RELEASE_ID}..."
gh api -X DELETE "repos/${REPO}/releases/${STAGING_RELEASE_ID}" >/dev/null 2>&1 || true

if [[ "$KEEP_SESSION" -eq 0 ]]; then
  log "Stopping Colab session '${SESSION}'..."
  "$COLAB_BIN" rm -s "$SESSION" >/dev/null 2>&1 || true
fi

log "Done."
