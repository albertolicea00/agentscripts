#!/usr/bin/env bash
# Download Archive.org files (.iso, .zip, .pkg, etc.) to Google Drive via Colab CLI SSH
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: colab-archive-dl.sh [options] <archive.org URL or identifier>

Options:
  -f, --filter <regex>    Include only filenames matching regex (case-insensitive)
  -x, --exclude <regex>   Exclude filenames matching regex (case-insensitive)
  -e, --ext <csv>         Comma-separated extensions (default: iso,zip,pkg,7z,chd,rar)
  -m, --max-gb <num>      Skip files larger than <num> GiB
  -c, --cookie <cookie>   Archive.org Cookie header (or set ARCHIVE_COOKIE / ~/.config/internetarchive/ia.ini)
  -k, --keep-local        Keep temporary file in /content/ after Drive SHA-1 verification
  -l, --list              Dry-run: list matching files and total size without connecting to Colab
  -h, --help              Show this help message
EOF
}

FILTER=""
EXCLUDE=""
EXTS="iso,zip,pkg,7z,chd,rar"
MAX_GB=""
COOKIE="${ARCHIVE_COOKIE:-}"
KEEP_LOCAL="0"
LIST_ONLY="0"
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--filter) FILTER="$2"; shift 2 ;;
    -x|--exclude) EXCLUDE="$2"; shift 2 ;;
    -e|--ext) EXTS="$2"; shift 2 ;;
    -m|--max-gb) MAX_GB="$2"; shift 2 ;;
    -c|--cookie) COOKIE="$2"; shift 2 ;;
    -k|--keep-local) KEEP_LOCAL="1"; shift ;;
    -l|--list) LIST_ONLY="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *) TARGET="$1"; shift ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  read -r -p "Archive.org URL or identifier: " TARGET
fi
if [[ -z "$TARGET" ]]; then
  usage >&2
  exit 1
fi

# Auto-detect Archive.org cookies from ~/.config/internetarchive/ia.ini or ~/.ia if not provided
if [[ -z "$COOKIE" ]]; then
  COOKIE="$(python3 -c '
import configparser
from pathlib import Path
for p in [Path.home() / ".config/internetarchive/ia.ini", Path.home() / ".ia"]:
    if p.is_file():
        cp = configparser.RawConfigParser()
        cp.read(p)
        if cp.has_section("cookies"):
            u = cp.get("cookies", "logged-in-user", fallback="").strip()
            s = cp.get("cookies", "logged-in-sig", fallback="").strip()
            if u and s:
                print(f"logged-in-user={u}; logged-in-sig={s}")
                break
' 2>/dev/null || true)"
fi

if [[ "$LIST_ONLY" == "1" ]]; then
  python3 - "$TARGET" "$EXTS" "$FILTER" "$EXCLUDE" "$MAX_GB" <<'LIST_EOF'
import json, re, sys, urllib.request
from urllib.parse import unquote, urlparse

raw, exts_csv, flt, exc, max_gb = sys.argv[1:6]
if "://" in raw:
    u = urlparse(raw)
    parts = u.path.strip("/").split("/")
    item = unquote(parts[1]) if len(parts) >= 2 else raw
else:
    item = raw
if item == "ni-romsets":
    item = "ni-roms"

exts = tuple("." + x.strip().lower().lstrip(".") for x in exts_csv.split(",") if x.strip())
data = json.loads(urllib.request.urlopen(f"https://archive.org/metadata/{item}", timeout=30).read())
selected = []
for f in data.get("files", []):
    name = f.get("name", "")
    if not name.lower().endswith(exts):
        continue
    if name.endswith(".torrent"):
        continue
    if flt and not re.search(flt, name, re.I):
        continue
    if exc and re.search(exc, name, re.I):
        continue
    sz_gb = int(f.get("size") or 0) / 1024**3
    if max_gb and sz_gb > float(max_gb):
        continue
    selected.append((name, sz_gb, bool(f.get("private"))))

total_gb = sum(x[1] for x in selected)
priv_count = sum(1 for x in selected if x[2])
print(f"Item: {item} | Matched: {len(selected)} files | Total: {total_gb:.2f} GiB | Locked (private): {priv_count}")
for name, sz_gb, priv in selected:
    lock = " [locked]" if priv else ""
    print(f"  - {name} ({sz_gb:.2f} GiB){lock}")
LIST_EOF
  exit 0
fi

for cmd in colab ssh; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

SESSION="${COLAB_SESSION:-colab}"
SSH_HOST="${COLAB_SSH_HOST:-colab}"

if ! colab sessions 2>/dev/null | grep -qE "\\b${SESSION}\\b"; then
  echo "Creating Colab session '$SESSION'..."
  colab new -s "$SESSION"
fi

if ! ssh "$SSH_HOST" "test -d /content/drive/MyDrive" 2>/dev/null; then
  echo "Mounting Google Drive on '$SESSION' (approve the browser OAuth prompt)..."
  colab drivemount -s "$SESSION" /content/drive
fi

echo "Starting HTTPS (--split=8) batch download + SHA-1 verification on '$SESSION'..."
ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=10 "$SSH_HOST" \
  "TARGET_ARG=$(printf '%q' "$TARGET") EXTS_ARG=$(printf '%q' "$EXTS") FILTER_ARG=$(printf '%q' "$FILTER") EXCLUDE_ARG=$(printf '%q' "$EXCLUDE") MAX_GB_ARG=$(printf '%q' "$MAX_GB") COOKIE_ARG=$(printf '%q' "$COOKIE") KEEP_LOCAL_ARG=$(printf '%q' "$KEEP_LOCAL") bash -s" <<'REMOTE_EOF'
set -euo pipefail
pip -q install requests
if ! command -v aria2c >/dev/null 2>&1; then
  apt-get -qq update
  apt-get -qq install -y aria2
fi

python3 -u - "$TARGET_ARG" "$EXTS_ARG" "$FILTER_ARG" "$EXCLUDE_ARG" "$MAX_GB_ARG" "$COOKIE_ARG" "$KEEP_LOCAL_ARG" <<'PY_EOF'
import hashlib
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import quote, unquote, urlparse
import requests

raw, exts_csv, flt, exc, max_gb, cookie, keep_local = sys.argv[1:8]
if "://" in raw:
    u = urlparse(raw)
    parts = u.path.strip("/").split("/")
    if u.scheme != "https" or u.hostname not in {"archive.org", "www.archive.org"}:
        raise ValueError("Use an archive.org HTTPS URL.")
    if len(parts) < 2 or parts[0] not in {"details", "download"}:
        raise ValueError("Use the item page (/details/<id> or /download/<id>).")
    item = unquote(parts[1])
else:
    item = raw.strip()
if item == "ni-romsets":
    item = "ni-roms"
if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", item):
    raise ValueError(f"Invalid identifier: {item!r}")

exts = tuple("." + x.strip().lower().lstrip(".") for x in exts_csv.split(",") if x.strip())
work = Path(f"/content/downloads/archive-torrents/{item}/verified")
dest = Path(f"/content/drive/MyDrive/CollabMedia/downloads/archive-torrents/{item}")
work.mkdir(parents=True, exist_ok=True)
dest.mkdir(parents=True, exist_ok=True)

def safe_path(base: Path, name: str) -> Path:
    path = base / name
    if not name or "\\" in name or Path(name).is_absolute():
        raise ValueError(f"Invalid path: {name!r}")
    if not path.resolve().is_relative_to(base.resolve()) or path.resolve() == base.resolve():
        raise ValueError(f"Path outside destination: {name!r}")
    return path

data = requests.get(f"https://archive.org/metadata/{item}", timeout=(15, 90)).json()
selected = []
for f in data.get("files", []):
    name = f.get("name", "")
    if not name.lower().endswith(exts) or name.endswith(".torrent"):
        continue
    if flt and not re.search(flt, name, re.I):
        continue
    if exc and re.search(exc, name, re.I):
        continue
    sz_gb = int(f.get("size") or 0) / 1024**3
    if max_gb and sz_gb > float(max_gb):
        continue
    selected.append(f)

if not selected:
    raise RuntimeError(f"No matching files found for {item}.")

locked = [f["name"] for f in selected if f.get("private")]
if locked and not cookie:
    raise RuntimeError(
        f"{len(locked)} matched file(s) are locked (private=true) on Archive.org. "
        "Provide ARCHIVE_COOKIE='logged-in-user=...; logged-in-sig=...' or pass --cookie."
    )

def verified(path: Path, info: dict) -> bool:
    if not path.is_file() or path.stat().st_size != int(info["size"]):
        return False
    digest = hashlib.sha1()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().lower() == info["sha1"].lower()

total_gb = sum(int(f["size"]) for f in selected) / 1024**3
print(f"Item: {item} | Files: {len(selected)} | Total: {total_gb:.2f} GiB", flush=True)

failures = []
for idx, f in enumerate(selected, 1):
    name = f["name"]
    tgt = safe_path(work, name)
    drive_tgt = safe_path(dest, name)
    if verified(drive_tgt, f):
        print(f"[{idx}/{len(selected)}] Already on Drive and verified: {name}", flush=True)
        if keep_local != "1" and tgt.is_file():
            tgt.unlink()
        continue

    sz_bytes = int(f["size"])
    sz = sz_bytes / 1024**3
    sha1 = f["sha1"]
    url = "https://archive.org/download/" + quote(item, safe="") + "/" + quote(name, safe="/")

    # If a single file exceeds free space on /content, download directly to Drive (.copying)
    free_local = shutil.disk_usage(work).free
    direct_to_drive = (sz_bytes + 2 * 1024**3) > free_local

    dl_target = drive_tgt.with_name(drive_tgt.name + ".copying") if direct_to_drive else tgt
    dl_target.parent.mkdir(parents=True, exist_ok=True)

    try:
        if direct_to_drive or not verified(tgt, f):
            print(f"[{idx}/{len(selected)}] Downloading {name} ({sz:.2f} GiB){' [direct-to-Drive]' if direct_to_drive else ''}...", flush=True)
            cmd = [
                "aria2c", "--no-conf=true", "--continue=true", "--auto-file-renaming=false",
                "--allow-overwrite=true", "--check-integrity=true", "--file-allocation=none",
                "--summary-interval=15", "--console-log-level=warn", "--max-tries=5",
                "--retry-wait=10", "--connect-timeout=30", "--timeout=60",
                f"--dir={dl_target.parent}", f"--out={dl_target.name}", "--split=8",
                "--max-connection-per-server=8", f"--checksum=sha-1={sha1}",
            ]
            if cookie:
                cmd.append(f"--header=Cookie: {cookie}")
            cmd.append(url)
            for attempt in range(1, 4):
                try:
                    subprocess.run(cmd, check=True)
                    break
                except subprocess.CalledProcessError as exc:
                    if attempt == 3:
                        raise
                    wait_s = 15 * attempt
                    print(f"[{idx}/{len(selected)}] aria2c exited {exc.returncode}; retrying in {wait_s}s (attempt {attempt}/3)...", flush=True)
                    time.sleep(wait_s)
            if not verified(dl_target, f):
                raise RuntimeError(f"SHA-1 verification failed: {name}")

        if direct_to_drive:
            os.replace(dl_target, drive_tgt)
            print(f"[{idx}/{len(selected)}] Saved and verified on Drive: {drive_tgt}", flush=True)
        else:
            drive_tgt.parent.mkdir(parents=True, exist_ok=True)
            partial = drive_tgt.with_name(drive_tgt.name + ".copying")
            print(f"[{idx}/{len(selected)}] Copying to Drive: {drive_tgt}...", flush=True)
            copied = 0
            next_report = 512 * 1024 * 1024
            with tgt.open("rb") as src_f, partial.open("wb") as dst_f:
                while True:
                    buf = src_f.read(16 * 1024 * 1024)
                    if not buf:
                        break
                    dst_f.write(buf)
                    copied += len(buf)
                    if copied >= next_report or copied == sz_bytes:
                        pct = copied * 100 // sz_bytes if sz_bytes else 100
                        print(f"  Copy progress: {copied / 1024**3:.2f}/{sz:.2f} GiB ({pct}%)", flush=True)
                        next_report += 512 * 1024 * 1024
            if not verified(partial, f):
                raise RuntimeError(f"Drive SHA-1 verification failed: {name}")
            os.replace(partial, drive_tgt)
            if keep_local != "1":
                tgt.unlink()
            print(f"[{idx}/{len(selected)}] Saved on Drive and cleaned local temp: {name}", flush=True)
    except Exception as err:
        failures.append((name, str(err)))
        print(f"[{idx}/{len(selected)}] ERROR for {name}: {err} (continuing batch)", flush=True)

if failures:
    print(f"BATCH_FINISHED_WITH_FAILURES ({len(failures)}):", flush=True)
    for fname, err in failures:
        print(f"  - {fname}: {err}", flush=True)
    sys.exit(1)

print("ALL_BATCH_DONE_ON_DRIVE", flush=True)
PY_EOF
REMOTE_EOF
