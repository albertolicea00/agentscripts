#!/usr/bin/env bash
# Download retro/PSP ROMs from romsfun.com in batch (handles Cloudflare, dynamic CDN tokens & resume)
# Usage: ./dl-romsfun-batch.sh <file_or_url...>

set -euo pipefail

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <urls_file | url1> [url2 ...]"
    echo "Example: $0 .workspace/psp-isos-dl.txt"
    echo "Example: $0 https://romsfun.com/roms/playstation-portable/game.html"
    exit 1
fi

OUT_DIR="${OUT_DIR:-$HOME/Downloads}"
mkdir -p "$OUT_DIR"

command -v python3 >/dev/null 2>&1 || { echo "Error: python3 is required"; exit 1; }

python3 -c "import cloudscraper, bs4" >/dev/null 2>&1 || {
    echo "Installing required Python dependencies (cloudscraper, beautifulsoup4)..."
    python3 -m pip install -q cloudscraper beautifulsoup4
}

export OUT_DIR

python3 - "$@" << 'EOF'
import os
import sys
import time
import json
import re
import zipfile
from urllib.parse import urljoin
import cloudscraper
from bs4 import BeautifulSoup

out_dir = os.environ.get("OUT_DIR", os.path.expanduser("~/Downloads"))
inputs = sys.argv[1:]

scraper = cloudscraper.create_scraper()
scraper.headers.update({
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
})

def parse_urls(args):
    urls = []
    for arg in args:
        if os.path.isfile(arg):
            with open(arg, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#"):
                        urls.append(line)
        elif arg.startswith("http"):
            urls.append(arg)
    # Deduplicate while preserving order
    return list(dict.fromkeys(urls))

def fetch_token(version_url):
    ajax_url = "https://romsfun.com/wp-admin/admin-ajax.php"
    headers = {
        "Referer": version_url,
        "X-Requested-With": "XMLHttpRequest",
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"
    }
    try:
        r = scraper.post(ajax_url, data="action=k_get_download", headers=headers, timeout=30)
        if r.status_code == 200:
            d = r.json()
            if d.get("success") and d.get("data", {}).get("download_url"):
                return d["data"]["download_url"], d["data"].get("file_name"), d["data"].get("file_size")
    except Exception as e:
        print(f"  [Warn] Token request error: {e}")
    return None, None, None

def resolve_game(game_url, version_num="1"):
    print(f"\nResolving: {game_url}")
    try:
        resp = scraper.get(game_url, timeout=30)
    except Exception as e:
        print(f"  [Error] Failed to fetch page: {e}")
        return None, None, None, None

    if resp.status_code != 200:
        print(f"  [Error] HTTP {resp.status_code} on {game_url}")
        return None, None, None, None

    soup = BeautifulSoup(resp.text, "html.parser")
    hub_url = None
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if "/download/" in href and not href.endswith(("#", ".png", ".jpg")):
            hub_url = urljoin(game_url, href)
            break

    if not hub_url:
        if "/download/" in game_url:
            hub_url = game_url
        else:
            print(f"  [Error] Could not locate download hub on page.")
            return None, None, None, None

    if re.search(r"/download/[^/]+/\d+$", hub_url):
        version_url = hub_url
    else:
        version_url = hub_url.rstrip("/") + f"/{version_num}"

    dl_url, file_name, file_size = fetch_token(version_url)
    return dl_url, file_name, file_size, version_url

def extract_archive(zip_path, target_dir):
    print(f"  Extracting archive: {os.path.basename(zip_path)}...")
    extracted_files = []
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            for item in zip_ref.namelist():
                if item.lower().endswith(('.iso', '.cso', '.pbp')):
                    zip_ref.extract(item, target_dir)
                    dest_file = os.path.join(target_dir, item)
                    extracted_files.append(dest_file)
                    print(f"  ✓ Extracted: {item} ({os.path.getsize(dest_file)/1024/1024:.1f} MB)")
        if extracted_files:
            os.remove(zip_path)
            print(f"  Removed zip archive to save space.")
            return extracted_files
    except Exception as e:
        print(f"  [Error] Failed to unzip {zip_path}: {e}")
    return []

def download_one(game_url):
    dl_url, file_name, file_size, version_url = resolve_game(game_url)
    if not dl_url:
        return False

    clean_path = dl_url.split("?")[0]
    ext = os.path.splitext(clean_path)[1] or ".zip"
    safe_name = re.sub(r'[\\/*?:"<>|]', "", file_name or "game") + ext
    out_path = os.path.join(out_dir, safe_name)

    # Check if ISO is already extracted
    base_name = os.path.splitext(safe_name)[0]
    for existing_ext in [".iso", ".cso", ".pbp"]:
        candidate = os.path.join(out_dir, base_name + existing_ext)
        if os.path.exists(candidate):
            print(f"  SKIP (already downloaded & extracted): {os.path.basename(candidate)}")
            return True

    print("  " + "─" * 50)
    print(f"  Game:   {file_name}")
    print(f"  Size:   {file_size or 'unknown'}")
    print(f"  Target: {out_path}")
    print("  " + "─" * 50)

    downloaded = 0
    if os.path.exists(out_path):
        downloaded = os.path.getsize(out_path)
        print(f"  Resuming from {downloaded/1024/1024:.1f} MB...")

    total_bytes = 0
    max_retries = 100
    retries = 0
    current_url = dl_url
    start_time = time.time()
    last_print = 0

    while True:
        try:
            headers = {"Referer": "https://romsfun.com/"}
            if downloaded > 0:
                headers["Range"] = f"bytes={downloaded}-"

            with scraper.get(current_url, stream=True, headers=headers, timeout=45) as r:
                if r.status_code in (403, 410):
                    print("\n  [Token expired, refreshing...]")
                    new_url, _, _ = fetch_token(version_url)
                    if new_url:
                        current_url = new_url
                        continue
                    else:
                        raise RuntimeError("Failed to refresh token after 403")

                if r.status_code not in (200, 206):
                    r.raise_for_status()

                if downloaded == 0:
                    total_bytes = int(r.headers.get("content-length", 0))
                elif total_bytes == 0 and "content-range" in r.headers:
                    total_bytes = int(r.headers["content-range"].split("/")[-1])
                elif total_bytes == 0:
                    total_bytes = downloaded + int(r.headers.get("content-length", 0))

                if total_bytes > 0 and downloaded >= total_bytes:
                    break

                with open(out_path, "ab" if downloaded > 0 else "wb") as f:
                    for chunk in r.iter_content(chunk_size=1024 * 512):
                        if chunk:
                            f.write(chunk)
                            downloaded += len(chunk)
                            now = time.time()
                            if now - last_print >= 1:
                                elapsed = now - start_time
                                speed_mb = (downloaded / (1024 * 1024)) / (elapsed if elapsed > 0 else 1)
                                pct = (downloaded / total_bytes * 100) if total_bytes > 0 else 0
                                print(f"\r  Downloading: {downloaded/1024/1024:.1f}/{total_bytes/1024/1024:.1f} MB ({pct:.1f}%) - {speed_mb:.2f} MB/s", end="", flush=True)
                                last_print = now

            if total_bytes > 0 and downloaded >= total_bytes:
                print(f"\n  ✓ Download finished: {out_path}")
                break

        except Exception as err:
            retries += 1
            if retries > max_retries:
                print(f"\n  [Error] Max retries exceeded ({max_retries}): {err}")
                return False
            print(f"\n  [Dropped: {err}. Reconnecting from {downloaded/1024/1024:.1f} MB (retry {retries}/{max_retries})...]")
            time.sleep(3)
            try:
                new_url, _, _ = fetch_token(version_url)
                if new_url:
                    current_url = new_url
            except Exception:
                pass

    if out_path.lower().endswith('.zip'):
        extract_archive(out_path, out_dir)

    return True

urls = parse_urls(inputs)
if not urls:
    print("No valid URLs found in inputs.")
    sys.exit(1)

print(f"=== Starting Batch Download for {len(urls)} Game(s) ===")
print(f"Output directory: {out_dir}")

for idx, url in enumerate(urls, 1):
    print(f"\n[{idx}/{len(urls)}] Processing...")
    success = download_one(url)
    if not success:
        print(f"  ⚠ Failed to download: {url}")
    time.sleep(2)

print("\n=== All Downloads Finished! ===")
EOF
