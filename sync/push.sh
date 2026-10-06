#!/usr/bin/env bash
# push.sh — Upload src/ notebooks from repo to Google Drive
# Requires: GOOGLE_APPLICATION_CREDENTIALS set to service account JSON
# Usage: ./sync/push.sh

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

echo "[push] Uploading src/ notebooks to Drive folder: $DRIVE_FOLDER_ID"

python3 - <<PYEOF
import os
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google.oauth2 import service_account

creds = service_account.Credentials.from_service_account_file(
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"],
    scopes=["https://www.googleapis.com/auth/drive.file"],
)
service = build("drive", "v3", credentials=creds)

folder_id = os.environ["DRIVE_FOLDER_ID"]
src_root = os.path.join("$ROOT_DIR", "src")

# Collect notebooks
notebooks = []
for root, _, files in os.walk(src_root):
    for f in files:
        if f.endswith(".ipynb"):
            notebooks.append(os.path.join(root, f))

print(f"  Found {len(notebooks)} notebooks.")

# Index existing files in Drive
existing = {}
results = service.files().list(
    q=f"'{folder_id}' in parents and trashed=false",
    fields="files(id, name)",
).execute()
for f in results.get("files", []):
    existing[f["name"]] = f["id"]

for nb_path in notebooks:
    name = os.path.basename(nb_path)
    media = MediaFileUpload(nb_path, mimetype="application/x-ipynb+json", resumable=True)

    if name in existing:
        service.files().update(fileId=existing[name], media_body=media).execute()
        print(f"  Updated: {name}")
    else:
        meta = {"name": name, "parents": [folder_id]}
        service.files().create(body=meta, media_body=media).execute()
        print(f"  Created: {name}")

print("Done.")
PYEOF
