# Scripts Changelog

Tracks every script added, changed, or fixed under `scripts/`.
**Do not put repo-level or notebooks changes here.**

Format: `Added | Changed | Fixed | Removed` under each date.

---

## 2026-11-14

- Changed: `scripts/downloads/colab-archive-dl.sh` — added multi-format support (`.iso`, `.zip`, `.pkg`, `.7z`, `.chd`, `.rar`), `--filter`/`--exclude`/`--max-gb`/`--list` flags, Archive.org login cookie support (`--cookie`, `ARCHIVE_COOKIE`, or `~/.config/internetarchive/ia.ini`), automatic local `/content/` cleanup after Drive SHA-1 verification, and direct-to-Drive fallback for files larger than Colab local storage.
- Added: `scripts/downloads/colab-archive-dl.sh` — download Archive.org `.iso` files to Google Drive via Colab CLI SSH (`aria2c` HTTPS `--split=8` + SHA-1 verification).

## 2026-10-09

- Added: `scripts/downloads/dl-romsfun-batch.sh` — download retro/PSP ROMs from romsfun.com in batch with Cloudflare bypass, dynamic CDN token resolution & resume.
- Added: `scripts/.colab-connect/` — Google Colab SSH bridge and remote execution tooling (`setup.sh`, `connect.sh`, `run.sh` via Cloudflare Tunnel).
- Changed: `scripts/Makefile` — added `setup-colab`, `connect-colab`, and `run-colab` targets.
- Changed: `scripts/.gitignore` — ignore `.colab-connect/.env`.

## 2026-10-06

- Added: `scripts/downloads/dl-tubi.sh` — downloads Tubi progressive MP4 from M3U8 Detector JSON export. Dedupes repeated segment URLs (single file, not real HLS).
- Added: `scripts/downloads/hls-local.sh` — downloads HLS or direct-video streams from M3U8 Detector JSON locally. Requires `curl` and `ffmpeg`.
- Added: `scripts/.sync-vps/` — VPS ↔ local rsync sync scripts (pull.sh / push.sh over SSH).
