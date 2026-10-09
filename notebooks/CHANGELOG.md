# Notebooks Changelog

Tracks every notebook added, changed, or fixed under `notebooks/`.
**Do not put repo-level or scripts changes here.**

Format: `Added | Changed | Fixed | Removed` under each date.

---

## 2026-10-09

- Changed: `notebooks/downloads/romsfun.ipynb` — download directly to Google Drive instead of `/content/` temp + copy. Mount Drive in setup cell, removed final copy cell. Better for unstable connections (files survive Colab disconnects).
- Fixed: `notebooks/downloads/romsfun.ipynb` — updated `find_download_url` with AJAX token resolver (`action=k_get_download`) to avoid downloading intermediate HTML hub pages.
- Added: `notebooks/utils/colab-connect.ipynb` — OpenSSH daemon + Cloudflare Tunnel bridge for remote SSH & command execution. Output → `CollabMedia/utils/colab-connect/session.json`.

## 2026-10-06

- Added: `notebooks/downloads/romsfun.ipynb` — batch PSP ROM downloader from romsfun.com. Widget URL input, cloudscraper, output → `CollabMedia/downloads/romsfun/`.
- Added: `notebooks/downloads/hls-colab.ipynb` — HLS/obfuscated stream downloader (moved from `m3u8-detector`). Supports TikTok CDN PNG-wrapped segments, M3U8 Detector JSON, direct MP4.
- Added: `notebooks/downloads/ytdlp-2drive.ipynb` — yt-dlp + EJS/PO-token solver (moved from `m3u8-detector`). Fixed Drive output path to `CollabMedia/downloads/ytdlp-2drive/`.
- Added: `notebooks/.sync-colab/` — Drive ↔ GitHub sync scripts (moved from `sync/`). OAuth via Colab Secrets, shell via service account.
