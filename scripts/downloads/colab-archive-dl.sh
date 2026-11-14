#!/usr/bin/env bash
# Download Archive.org ISOs to Google Drive via Colab CLI SSH
set -euo pipefail

for cmd in colab ssh; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  read -r -p "Archive.org URL or identifier: " TARGET
fi
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <archive.org URL or identifier>" >&2
  exit 1
fi

SESSION="${COLAB_SESSION:-colab}"
SSH_HOST="${COLAB_SSH_HOST:-colab}"

# Ensure the named session exists with both Jupyter kernel and SSH endpoints.
if ! colab sessions 2>/dev/null | grep -qE "\\b${SESSION}\\b"; then
  echo "Creating Colab session '$SESSION'..."
  colab new -s "$SESSION"
fi

# Mount Google Drive first via Jupyter kernel API if not already mounted.
if ! ssh "$SSH_HOST" "test -d /content/drive/MyDrive" 2>/dev/null; then
  echo "Mounting Google Drive on '$SESSION' (approve the browser OAuth prompt)..."
  colab drivemount -s "$SESSION" /content/drive
fi

echo "Starting HTTPS (--split=8) download + SHA-1 verification on '$SESSION'..."
ssh "$SSH_HOST" "TARGET_ARG='$TARGET' bash -s" <<'REMOTE_EOF'
set -euo pipefail
pip -q install requests
if ! command -v aria2c >/dev/null 2>&1; then
  apt-get -qq update
  apt-get -qq install -y aria2
fi

python3 -u - "$TARGET_ARG" <<'PY_EOF'
import hashlib
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote, unquote, urlparse
import requests

raw = sys.argv[1].strip()
if "://" in raw:
    u = urlparse(raw)
    parts = u.path.strip("/").split("/")
    if u.scheme != "https" or u.hostname not in {"archive.org", "www.archive.org"}:
        raise ValueError("Use an archive.org HTTPS URL.")
    if len(parts) != 2 or parts[0] not in {"details", "download"}:
        raise ValueError("Use the item page (/details/<id> or /download/<id>).")
    item = unquote(parts[1])
else:
    item = raw
if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", item):
    raise ValueError(f"Invalid identifier: {item!r}")

work = Path(f"/content/downloads/archive-torrents/{item}/verified")
dest = Path(f"/content/drive/MyDrive/CollabMedia/downloads/archive-torrents/{item}")
work.mkdir(parents=True, exist_ok=True)
dest.mkdir(parents=True, exist_ok=True)

data = requests.get(f"https://archive.org/metadata/{item}", timeout=(15, 90)).json()
selected = [f for f in data.get("files", []) if not f.get("private") and f["name"].lower().endswith(".iso")]
if not selected:
    raise RuntimeError(f"No public .iso files found for {item}.")

def verified(path: Path, info: dict) -> bool:
    if not path.is_file() or path.stat().st_size != int(info["size"]):
        return False
    digest = hashlib.sha1()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().lower() == info["sha1"].lower()

for f in selected:
    name = f["name"]
    tgt = work / name
    drive_tgt = dest / name
    if verified(drive_tgt, f):
        print(f"Already on Drive and verified: {drive_tgt}", flush=True)
        continue
    if not verified(tgt, f):
        url = "https://archive.org/download/" + quote(item, safe="") + "/" + quote(name, safe="/")
        sz = int(f["size"]) / 1024**3
        sha1 = f["sha1"]
        print(f"Downloading {name} ({sz:.2f} GiB)...", flush=True)
        subprocess.run([
            "aria2c", "--no-conf=true", "--continue=true", "--auto-file-renaming=false",
            "--allow-overwrite=true", "--check-integrity=true", "--file-allocation=none",
            "--summary-interval=15", "--console-log-level=warn", "--max-tries=5",
            "--retry-wait=10", "--connect-timeout=30", "--timeout=60",
            f"--dir={tgt.parent}", f"--out={tgt.name}", "--split=8",
            "--max-connection-per-server=8", f"--checksum=sha-1={sha1}", url,
        ], check=True)
        if not verified(tgt, f):
            raise RuntimeError(f"Local SHA-1 verification failed: {name}")
    partial = drive_tgt.with_name(drive_tgt.name + ".copying")
    print(f"Copying to Drive: {drive_tgt}...", flush=True)
    shutil.copyfile(tgt, partial)
    if not verified(partial, f):
        raise RuntimeError(f"Drive SHA-1 verification failed: {name}")
    os.replace(partial, drive_tgt)
    print(f"Saved and verified on Drive: {drive_tgt}", flush=True)
PY_EOF
REMOTE_EOF
