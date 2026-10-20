#!/usr/bin/env bash
# Resilient Google Drive downloader: folder/split parts, browser cookie sync, range resume & auto-join
# Usage: ./dl-gdrive-resilient.sh [options] <drive_url_or_id_or_webloc...>

set -euo pipefail

show_help() {
    cat << 'EOF'
Usage: dl-gdrive-resilient.sh [options] <url_or_id_or_file...>

Ultra-resilient Google Drive downloader designed for large files and multi-part archives.
Handles browser authentication, network micro-cuts, automatic Range resuming, and joining.

Inputs:
  - Google Drive folder URL:   https://drive.google.com/drive/folders/<FOLDER_ID>
  - Google Drive file URL:     https://drive.google.com/file/d/<FILE_ID>/view
  - Google Drive .webloc file: path/to/link.webloc (Apple Web Internet Location)
  - Raw Drive folder or file ID: 1J-2iarladmpT4Tq8715V-VA8H7Ac1e1g
  - Text file with URLs:       urls.txt (one URL/ID per line)

Options:
  -o, --out-dir <dir>       Destination directory (default: current dir or $OUT_DIR)
  -b, --browser <name>      Browser to import cookies from: chrome, safari, firefox, brave, edge (default: chrome)
  -j, --join [output_file]  Auto-join split parts (part_*.part) into a single file upon completion
  -p, --pause-after <n>     Pause downloads after completing part N (1-based index or part name)
  --no-refresh              Disable AppleScript tab reloading (for headless / non-macOS environments)
  -h, --help                Show this help message

Examples:
  ./dl-gdrive-resilient.sh "https://drive.google.com/drive/folders/1J-2iarladmpT4Tq8715V-VA8H7Ac1e1g"
  ./dl-gdrive-resilient.sh -o ~/Downloads/Ubuntu --join ubuntu-24.04.iso ubuntu_split.webloc
  ./dl-gdrive-resilient.sh --pause-after 3 "https://drive.google.com/drive/folders/<ID>"
EOF
    exit 0
}

OUT_DIR="${OUT_DIR:-.}"
BROWSER="chrome"
JOIN_OUTPUT=""
DO_JOIN=0
PAUSE_AFTER=""
NO_REFRESH=0
INPUTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -o|--out-dir)
            OUT_DIR="$2"
            shift 2
            ;;
        -b|--browser)
            BROWSER="$2"
            shift 2
            ;;
        -j|--join)
            DO_JOIN=1
            if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                JOIN_OUTPUT="$2"
                shift 2
            else
                shift 1
            fi
            ;;
        -p|--pause-after)
            PAUSE_AFTER="$2"
            shift 2
            ;;
        --no-refresh)
            NO_REFRESH=1
            shift 1
            ;;
        *)
            INPUTS+=("$1")
            shift 1
            ;;
    esac
done

if [[ ${#INPUTS[@]} -eq 0 ]]; then
    echo "Error: Missing input URL, folder ID, or file." >&2
    echo "Run with --help for usage details." >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

command -v python3 >/dev/null 2>&1 || { echo "Error: python3 is required" >&2; exit 1; }

python3 -c "import requests, gdown" >/dev/null 2>&1 || {
    echo "Installing required Python dependencies (requests, gdown)..."
    python3 -m pip install -q requests gdown
}

export OUT_DIR BROWSER DO_JOIN JOIN_OUTPUT PAUSE_AFTER NO_REFRESH

python3 - "${INPUTS[@]}" << 'EOF'
import os
import sys
import time
import json
import re
import plistlib
import subprocess
from urllib.parse import urlparse, parse_qs
import requests
from gdown.download import _get_session, get_url_from_gdrive_confirmation
from gdown.__main__ import _import_cookies_from_browser

OUT_DIR = os.path.abspath(os.environ.get("OUT_DIR", "."))
BROWSER = os.environ.get("BROWSER", "chrome").lower()
DO_JOIN = os.environ.get("DO_JOIN", "0") == "1"
JOIN_OUTPUT = os.environ.get("JOIN_OUTPUT", "").strip()
PAUSE_AFTER = os.environ.get("PAUSE_AFTER", "").strip()
NO_REFRESH = os.environ.get("NO_REFRESH", "0") == "1"

COOKIES_FILE = os.path.expanduser(f"~/.cache/gdown/cookies_{BROWSER}.txt")
STATUS_FILE = os.path.join(OUT_DIR, "download_status.json")

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(os.path.dirname(COOKIES_FILE), exist_ok=True)

def refresh_session_from_browser(target_url=None):
    """Refreshes active Google Drive tab in the browser on macOS and extracts cookies."""
    if NO_REFRESH or sys.platform != "darwin":
        try:
            n = _import_cookies_from_browser(browser=BROWSER, cookies_file=COOKIES_FILE)
            return True
        except Exception as e:
            print(f"[AUTH] Advertencia importando cookies de {BROWSER}: {e}", flush=True)
            return False

    browser_app_map = {
        "chrome": "Google Chrome",
        "brave": "Brave Browser",
        "edge": "Microsoft Edge",
    }
    app_name = browser_app_map.get(BROWSER, "Google Chrome")

    if target_url:
        print(f"[AUTH] Asegurando sesión activa en {app_name}...", flush=True)
        osa = f'''
        tell application "{app_name}"
            set found to false
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t contains "{target_url}" then
                        tell t to reload
                        set found to true
                        exit repeat
                    end if
                end repeat
                if found then exit repeat
            end repeat
            if not found then
                make new tab at end of tabs of window 1 with properties {{URL:"{target_url}"}}
            end if
        end tell
        '''
        try:
            subprocess.run(["osascript", "-e", osa], capture_output=True, timeout=5)
            time.sleep(2)
        except Exception:
            pass

    try:
        n = _import_cookies_from_browser(browser=BROWSER, cookies_file=COOKIES_FILE)
        print(f"[AUTH] Sincronizadas {n} cookies desde {app_name}.", flush=True)
        return True
    except Exception as e:
        print(f"[AUTH] Advertencia importando cookies: {e}", flush=True)
        return False

def get_session():
    sess, _ = _get_session(
        proxy=None,
        use_cookies=True,
        user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36",
        cookies_file=COOKIES_FILE,
    )
    return sess

def extract_id_from_url(url_or_id):
    url_or_id = url_or_id.strip()
    if "/" not in url_or_id and len(url_or_id) >= 20:
        return url_or_id, "unknown"
    
    # Check folder URL
    m = re.search(r'/folders/([a-zA-Z0-9_-]{20,})', url_or_id)
    if m:
        return m.group(1), "folder"
    
    # Check file /d/ URL
    m = re.search(r'/file/d/([a-zA-Z0-9_-]{20,})', url_or_id)
    if m:
        return m.group(1), "file"
    
    # Check uc?id= URL
    m = re.search(r'[?&]id=([a-zA-Z0-9_-]{20,})', url_or_id)
    if m:
        return m.group(1), "file"
    
    return url_or_id, "unknown"

def parse_input_target(arg):
    if os.path.isfile(arg):
        # Check if .webloc
        if arg.lower().endswith(".webloc"):
            try:
                with open(arg, "rb") as f:
                    pl = plistlib.load(f)
                    url = pl.get("URL")
                    if url:
                        print(f"[INPUT] Extraído enlace desde .webloc: {url}", flush=True)
                        return [url]
            except Exception:
                try:
                    with open(arg, "r", errors="ignore") as f:
                        text = f.read()
                        m = re.search(r'https?://[^\s<>"\'\)]+', text)
                        if m:
                            return [m.group(0)]
                except Exception:
                    pass
        # Text file with URLs
        urls = []
        with open(arg, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    urls.append(line)
        return urls
    return [arg]

def discover_folder_files(sess, folder_id):
    url = f"https://drive.google.com/drive/folders/{folder_id}"
    print(f"[FOLDER] Explorando carpeta de Drive: {url}...", flush=True)
    refresh_session_from_browser(target_url=url)
    sess = get_session()
    
    res = sess.get(url, timeout=(10, 20))
    if res.status_code != 200:
        raise RuntimeError(f"Error accediendo a la carpeta (HTTP {res.status_code})")
    
    html = res.text
    # Extract files and IDs
    matches = re.findall(r'aria-label=[\"\']([^\"\']+?)(?:\s+(?:Binary|PDF|ZIP|RAR|Audio|Video|Image|Document|Spreadsheet))?[\"\'][^>]*?ssk=[\"\'][^:\'\"]*:[^:\'\"]*:([a-zA-Z0-9_-]{28,35})-\d+-\d+[\"\']', html)
    
    seen = set()
    files = []
    ignored_prefixes = ("Modified ", "Size:", "Storage used:", "More actions")
    
    for name, fid in matches:
        name = name.strip()
        if any(name.startswith(p) for p in ignored_prefixes):
            continue
        if name not in seen:
            seen.add(name)
            files.append({"name": name, "id": fid})
    
    # Natural sort
    def natural_key(item):
        return [int(c) if c.isdigit() else c.lower() for c in re.split(r'(\d+)', item["name"])]
    
    files.sort(key=natural_key)
    return files

def resolve_download_url(sess, file_id, folder_url=None):
    for attempt in range(3):
        try:
            res = sess.get(f"https://drive.google.com/uc?id={file_id}", timeout=(10, 15))
            if "accounts.google.com" in res.url or res.status_code in (401, 403):
                print("[AUTH] Sesión expirada al resolver enlace. Refrescando...", flush=True)
                refresh_session_from_browser(folder_url)
                sess = get_session()
                continue
            if "Content-Disposition" in res.headers or "application/octet-stream" in res.headers.get("Content-Type", ""):
                filename = None
                cd = res.headers.get("Content-Disposition", "")
                m = re.search(r'filename\*?=(?:UTF-8\'\')?["\']?([^"\';]+)["\']?', cd)
                if m:
                    filename = m.group(1).strip()
                return res.url, filename, sess
            url = get_url_from_gdrive_confirmation(res.text)
            return url, None, sess
        except Exception as e:
            print(f"[RESOLVE] Intento {attempt+1} falló al resolver enlace: {e}", flush=True)
            refresh_session_from_browser(folder_url)
            sess = get_session()
            time.sleep(3)
    raise RuntimeError(f"No se pudo obtener enlace de descarga para {file_id}")

def load_status():
    if os.path.exists(STATUS_FILE):
        try:
            with open(STATUS_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {"completed": [], "current": None, "total": 0}

def save_status(status):
    with open(STATUS_FILE, "w") as f:
        json.dump(status, f, indent=2)

def download_file_resilient(file_info, index, total_files, status, folder_url=None):
    name = file_info["name"]
    file_id = file_info["id"]
    target_path = os.path.join(OUT_DIR, name)
    tmp_path = f"{target_path}.tmp"

    if name in status.get("completed", []) and os.path.exists(target_path):
        size_mb = os.path.getsize(target_path) / (1024 * 1024)
        print(f"[{index}/{total_files}] [YA COMPLETADO] {name} ({size_mb:.2f} MB). Omitiendo.", flush=True)
        return True

    print(f"\n=======================================================", flush=True)
    print(f"[{index}/{total_files}] PROCESANDO: {name} (ID: {file_id})", flush=True)
    print(f"=======================================================", flush=True)

    status["current"] = name
    save_status(status)

    sess = get_session()
    download_url = None
    total_size = None
    consecutive_errors = 0

    while True:
        curr_bytes = os.path.getsize(tmp_path) if os.path.exists(tmp_path) else 0

        if not download_url:
            try:
                download_url, resolved_name, sess = resolve_download_url(sess, file_id, folder_url)
                if resolved_name and name == file_id:
                    name = resolved_name
                    target_path = os.path.join(OUT_DIR, name)
                    tmp_path = f"{target_path}.tmp"
            except Exception as e:
                print(f"[{name}] Error resolviendo URL: {e}. Reintentando en 5s...", flush=True)
                time.sleep(5)
                continue

        if total_size is None:
            try:
                head_res = sess.get(download_url, headers={"Range": f"bytes={curr_bytes}-{curr_bytes+1023}"}, timeout=(10, 15), stream=True)
                cr = head_res.headers.get("Content-Range", "")
                if "/" in cr:
                    total_size = int(cr.split("/")[-1])
                head_res.close()
            except Exception:
                pass

        if total_size and curr_bytes >= total_size:
            print(f"[{name}] Tamaño completo alcanzado ({curr_bytes} bytes).", flush=True)
            break

        headers = {}
        if curr_bytes > 0:
            headers["Range"] = f"bytes={curr_bytes}-"
            print(f"[{name}] Reanudando desde byte {curr_bytes} ({curr_bytes / (1024*1024):.2f} MB)...", flush=True)
        else:
            print(f"[{name}] Iniciando descarga desde el inicio...", flush=True)

        try:
            r = sess.get(download_url, headers=headers, stream=True, timeout=(10, 20))

            if r.status_code in (401, 403) or "accounts.google.com" in r.url:
                print(f"[{name}] Sesión expirada durante descarga. Renovando...", flush=True)
                refresh_session_from_browser(folder_url)
                sess = get_session()
                download_url = None
                time.sleep(2)
                continue

            if r.status_code not in (200, 206):
                print(f"[{name}] HTTP status inesperado: {r.status_code}. Reintentando enlace...", flush=True)
                download_url = None
                time.sleep(3)
                continue

            cr = r.headers.get("Content-Range", "")
            if "/" in cr:
                total_size = int(cr.split("/")[-1])
            elif r.status_code == 200:
                total_size = int(r.headers.get("Content-Length", 0))

            last_report_time = time.time()
            bytes_since_report = 0

            with open(tmp_path, "ab") as f:
                for chunk in r.iter_content(chunk_size=128 * 1024):
                    if not chunk:
                        break
                    f.write(chunk)
                    curr_bytes += len(chunk)
                    bytes_since_report += len(chunk)
                    consecutive_errors = 0

                    now = time.time()
                    if now - last_report_time >= 3.0:
                        speed_kbs = (bytes_since_report / 1024.0) / (now - last_report_time)
                        curr_mb = curr_bytes / (1024 * 1024)
                        if total_size:
                            tot_mb = total_size / (1024 * 1024)
                            pct = (curr_bytes / total_size) * 100.0
                            rem_bytes = max(0, total_size - curr_bytes)
                            eta_sec = (rem_bytes / 1024.0) / max(speed_kbs, 1.0)
                            eta_str = f"{int(eta_sec // 60)}m {int(eta_sec % 60)}s"
                            print(f"[{name}] {curr_mb:.1f}/{tot_mb:.1f} MB ({pct:.1f}%) | {speed_kbs:.1f} kB/s | ETA: {eta_str}", flush=True)
                        else:
                            print(f"[{name}] {curr_mb:.1f} MB | {speed_kbs:.1f} kB/s", flush=True)
                        last_report_time = now
                        bytes_since_report = 0

            if total_size and os.path.getsize(tmp_path) >= total_size:
                break

        except (requests.exceptions.Timeout, requests.exceptions.ConnectionError, requests.exceptions.ChunkedEncodingError) as e:
            consecutive_errors += 1
            curr_mb = os.path.getsize(tmp_path) / (1024 * 1024) if os.path.exists(tmp_path) else 0
            print(f"[{name}] [REANUDANDO] Micro-corte de red detectado en {curr_mb:.1f} MB ({type(e).__name__}). Reintentos consecutivos: {consecutive_errors}.", flush=True)
            if consecutive_errors >= 2:
                print(f"[{name}] Renovando enlace de descarga y refrescando sesión desde el navegador...", flush=True)
                download_url = None
                refresh_session_from_browser(folder_url)
                sess = get_session()
                consecutive_errors = 0
            time.sleep(2)
        except Exception as e:
            print(f"[{name}] Error temporal: {e}. Reanudando en 3s...", flush=True)
            download_url = None
            time.sleep(3)

    final_size = os.path.getsize(tmp_path)
    if total_size and final_size != total_size:
        print(f"[{name}] ERROR: El tamaño final ({final_size}) no coincide con el esperado ({total_size}).", flush=True)
        return False

    os.rename(tmp_path, target_path)
    print(f"\n[{index}/{total_files}] >>> [VERIFICADO 100%] {name} completado con éxito ({final_size / (1024*1024):.2f} MB).", flush=True)
    if name not in status["completed"]:
        status["completed"].append(name)
    status["current"] = None
    save_status(status)
    return True

def auto_join_parts(files_list):
    part_names = [f["name"] for f in files_list if re.search(r'part[_-]?\d+', f["name"], re.IGNORECASE)]
    if not part_names:
        print("[JOIN] No se detectaron archivos de partes divididas para unir.", flush=True)
        return
    
    # Natural sort
    def natural_key(name):
        return [int(c) if c.isdigit() else c.lower() for c in re.split(r'(\d+)', name)]
    
    part_names.sort(key=natural_key)
    
    out_name = JOIN_OUTPUT
    if not out_name:
        # Infer name from common prefix
        first = part_names[0]
        base = re.sub(r'[._-]part[._-]?\d+.*$', '', first, flags=re.IGNORECASE)
        if not base or base == first:
            base = "combined_output"
        out_name = f"{base}.iso"

    final_joined_path = os.path.join(OUT_DIR, out_name)
    print(f"\n[JOIN] Uniendo {len(part_names)} partes en: {final_joined_path}...", flush=True)

    expected_total = sum(os.path.getsize(os.path.join(OUT_DIR, p)) for p in part_names if os.path.exists(os.path.join(OUT_DIR, p)))
    
    with open(final_joined_path, "wb") as outfile:
        for p in part_names:
            src = os.path.join(OUT_DIR, p)
            print(f"  + Concatenando {p}...", flush=True)
            with open(src, "rb") as infile:
                while True:
                    buf = infile.read(4 * 1024 * 1024)
                    if not buf:
                        break
                    outfile.write(buf)

    actual_size = os.path.getsize(final_joined_path)
    print(f"[JOIN] ¡Unión completada exitosamente! Tamaño total: {actual_size / (1024*1024):.2f} MB ({actual_size} bytes).", flush=True)
    if expected_total == actual_size:
        print("[JOIN] Verificación por suma de bytes: EXACTA (100% OK) ✅", flush=True)

    # Inspect file format if tool available
    try:
        res = subprocess.run(["file", final_joined_path], capture_output=True, text=True)
        if res.returncode == 0:
            print(f"[FORMATO] {res.stdout.strip()}", flush=True)
    except Exception:
        pass

def main():
    raw_args = sys.argv[1:]
    targets = []
    for arg in raw_args:
        targets.extend(parse_input_target(arg))

    if not targets:
        print("Error: No se proporcionaron URLs o archivos válidos.", flush=True)
        sys.exit(1)

    all_files = []
    folder_url = None

    for target in targets:
        target_id, kind = extract_id_from_url(target)
        if kind == "folder" or "folders" in target:
            folder_url = f"https://drive.google.com/drive/folders/{target_id}"
            sess = get_session()
            folder_files = discover_folder_files(sess, target_id)
            all_files.extend(folder_files)
        else:
            all_files.append({"id": target_id, "name": target_id})

    if not all_files:
        print("Error: No se encontraron archivos para descargar.", flush=True)
        sys.exit(1)

    status = load_status()
    status["total"] = len(all_files)
    save_status(status)

    print(f"\n=== INICIANDO DESCARGA ULTRA-RESILIENTE ({len(all_files)} ARCHIVOS) ===", flush=True)
    print(f"Destino: {OUT_DIR}")
    print(f"Navegador de autenticación: {BROWSER}")
    if PAUSE_AFTER:
        print(f"Pausa programada tras completar: {PAUSE_AFTER}")

    for idx, item in enumerate(all_files, start=1):
        success = download_file_resilient(item, idx, len(all_files), status, folder_url)
        if not success:
            print(f"[ERROR FATAL] Falló la descarga de {item['name']}.", flush=True)
            sys.exit(1)

        # Check pause condition
        if PAUSE_AFTER:
            if str(idx) == PAUSE_AFTER or item["name"] == PAUSE_AFTER:
                print(f"\n[PAUSA] Condición de pausa alcanzada tras finalizar {item['name']}. Deteniendo descargas.", flush=True)
                sys.exit(0)

    print("\n=======================================================", flush=True)
    print(f"=== TODAS LAS {len(all_files)} PARTES DESCARGADAS Y VERIFICADAS ===", flush=True)
    print("=======================================================", flush=True)

    if DO_JOIN:
        auto_join_parts(all_files)

if __name__ == "__main__":
    main()
EOF
