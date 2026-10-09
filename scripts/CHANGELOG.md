# Scripts Changelog

Tracks every script added, changed, or fixed under `scripts/`.
**Do not put repo-level or notebooks changes here.**

Format: `Added | Changed | Fixed | Removed` under each date.

---

## 2026-10-09

- Added: `scripts/.colab-connect/` — Google Colab SSH bridge and remote execution tooling (`setup.sh`, `connect.sh`, `run.sh` via Cloudflare Tunnel).
- Changed: `scripts/Makefile` — added `setup-colab`, `connect-colab`, and `run-colab` targets.
- Changed: `scripts/.gitignore` — ignore `.colab-connect/.env`.

## 2026-10-06

- Added: `scripts/downloads/dl-tubi.sh` — downloads Tubi progressive MP4 from M3U8 Detector JSON export. Dedupes repeated segment URLs (single file, not real HLS).
- Added: `scripts/downloads/hls-local.sh` — downloads HLS or direct-video streams from M3U8 Detector JSON locally. Requires `curl` and `ffmpeg`.
- Added: `scripts/.sync-vps/` — VPS ↔ local rsync sync scripts (pull.sh / push.sh over SSH).
