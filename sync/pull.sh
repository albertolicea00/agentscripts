#!/usr/bin/env bash
# pull.sh — Download notebooks from Google Drive into src/
# Requires: gcloud CLI authenticated, or GOOGLE_APPLICATION_CREDENTIALS set
# Usage: ./sync/pull.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

: "${DRIVE_FOLDER_ID:?Set DRIVE_FOLDER_ID in sync/.env}"
: "${GOOGLE_APPLICATION_CREDENTIALS:?Set GOOGLE_APPLICATION_CREDENTIALS in sync/.env}"

SRC_DIR="$ROOT_DIR/src/drive-sync"
mkdir -p "$SRC_DIR"

echo "[pull] Listing Drive folder: $DRIVE_FOLDER_ID"

python3 - <<PYEOF
import os, io, sys
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload
from google.oauth2 import service_account

creds = service_account.Credentials.from_service_account_file(
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"],
    scopes=["https://www.googleapis.com/auth/drive.readonly"],
)
service = build("drive", "v3", credentials=creds)

folder_id = os.environ["DRIVE_FOLDER_ID"]
out_dir = "$SRC_DIR"

results = service.files().list(
    q=f"'{folder_id}' in parents and trashed=false",
    fields="files(id, name, mimeType)",
).execute()

files = results.get("files", [])
print(f"  Found {len(files)} files.")

for f in files:
    name = f["name"]
    if not name.endswith(".ipynb"):
        name += ".ipynb"

    # Export Colab notebooks as Jupyter
    if f["mimeType"] == "application/vnd.google.colaboratory":
        request = service.files().export_media(fileId=f["id"], mimeType="application/x-ipynb+json")
    else:
        request = service.files().get_media(fileId=f["id"])

    fh = io.BytesIO()
    downloader = MediaIoBaseDownload(fh, request)
    done = False
    while not done:
        _, done = downloader.next_chunk()

    out_path = os.path.join(out_dir, name)
    with open(out_path, "wb") as fp:
        fp.write(fh.getvalue())
    print(f"  Saved: {out_path}")

print("Done.")
PYEOF
