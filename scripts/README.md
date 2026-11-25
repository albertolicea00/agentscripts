# scripts/

Local shell scripts organized by category, with VPS sync tooling in `.sync-vps/`.

```
scripts/
├── .colab-connect/         # Google Colab SSH bridge & remote execution (Cloudflare Tunnel)
├── .sync-vps/              # VPS ↔ local sync (rsync over SSH)
├── utils/
│   ├── colab-gh-release-upload.sh  # Resumable GitHub Release uploader via Colab CLI SSH (chunked rsync + SHA-256 + fast Colab upload)
│   ├── colab-godot-build.sh        # Clone a Godot Git repo on Colab, export debug/release APK/EXE, and copy to Google Drive
│   ├── colab-rclone.sh             # Opt-in rclone Google Drive setup/teardown for Colab SSH (disabled by default)
│   └── gh-release-upload-resilient.sh # Sequential GitHub Release asset uploader hardened for slow/unstable links
└── downloads/
    ├── colab-archive-dl.sh    # Batch Archive.org downloader to Google Drive via Colab CLI SSH (--filter, --max-gb, --cookie, auto-cleanup)
    ├── dl-gdrive-resilient.py # Resilient Google Drive downloader (folder/split parts, cookie sync, range resume & auto-join)
    ├── dl-romsfun-batch.sh # Download retro/PSP ROMs from romsfun.com in batch from file or URL list
    ├── dl-tubi.sh          # Download Tubi progressive MP4 from M3U8 Detector JSON
    └── hls-local.sh        # Download HLS or direct streams locally (requires ffmpeg)
```

## Usage

```bash
make help                 # list all commands (sync + scripts)
make run-colab-archive-dl # run scripts/downloads/colab-archive-dl.sh
make run-dl-gdrive-resilient # run scripts/downloads/dl-gdrive-resilient.py
make run-dl-romsfun-batch # run scripts/downloads/dl-romsfun-batch.sh
make run-dl-tubi          # run scripts/downloads/dl-tubi.sh
make run-hls-local        # run scripts/downloads/hls-local.sh
make run-colab-gh-release-upload # run scripts/utils/colab-gh-release-upload.sh
make run-colab-godot-build # run scripts/utils/colab-godot-build.sh
make run-colab-rclone     # run scripts/utils/colab-rclone.sh (opt-in rclone for Colab)
make run-gh-release-upload-resilient # run scripts/utils/gh-release-upload-resilient.sh

make setup-vps            # first-time: create .sync-vps/.env from template
make pull-vps             # VPS → local scripts/
make push-vps             # local scripts/ → VPS

make setup-colab          # setup SSH keys & cloudflared for Colab
make connect-colab        # connect to Colab instance via SSH
```

Or from inside this folder:
```bash
make run-dl-tubi
```

## downloads

| Script | Command | Description |
|---|---|---|
| [downloads/colab-archive-dl.sh](downloads/colab-archive-dl.sh) | `make run-colab-archive-dl` | Downloads Archive.org items (`.iso`, `.zip`, `.pkg`, `.7z`, `.chd`, `.rar`) to Google Drive via Colab CLI SSH (`aria2c` HTTPS `--split=8` + SHA-1 verification). Supports `--filter`, `--exclude`, `--max-gb`, `--list`, Archive.org cookies (`--cookie` / `ARCHIVE_COOKIE`), automatic `/content/` cleanup after Drive copy, and direct-to-Drive mode when a file exceeds Colab local disk. |
| [downloads/dl-gdrive-resilient.py](downloads/dl-gdrive-resilient.py) | `make run-dl-gdrive-resilient` | Resilient Google Drive downloader: handles folders, split parts, Chrome/browser cookie sync, Range resuming, and auto-joining. |
| [downloads/dl-romsfun-batch.sh](downloads/dl-romsfun-batch.sh) | `make run-dl-romsfun-batch` | Downloads retro/PSP ROMs from romsfun.com in batch from file or URL list. Handles Cloudflare, dynamic CDN tokens, resume, and extraction. |
| [downloads/dl-tubi.sh](downloads/dl-tubi.sh) | `make run-dl-tubi` | Downloads Tubi progressive MP4 from an M3U8 Detector JSON export. Dedupes repeated segment URLs (single file, not real HLS chunks). |
| [downloads/hls-local.sh](downloads/hls-local.sh) | `make run-hls-local` | Downloads HLS or direct video streams from M3U8 Detector JSON. Requires `curl` and `ffmpeg`. |

## utils

| Script | Command | Description |
|---|---|---|
| [utils/colab-gh-release-upload.sh](utils/colab-gh-release-upload.sh) | `make run-colab-gh-release-upload` | Resumable GitHub Release uploader for slow/unstable links via Google Colab CLI SSH: splits large files into chunks (or reuses `--parts-dir`), streams each part to Colab with `rsync --partial --inplace` + per-part SHA-256 verification, checkpoints each verified chunk immediately to a hidden temporary GitHub Draft Release (surviving Colab VM resets and local restarts), reassembles & verifies full SHA-256 on Colab, uploads directly to GitHub Releases from Colab's datacenter network, and deletes the staging draft. |
| [utils/colab-godot-build.sh](utils/colab-godot-build.sh) | `make run-colab-godot-build` | Clones a Godot Git repository on Google Colab via CLI SSH, installs headless Godot + export templates + Android debug signing (`apksigner`/`debug.keystore`), exports Android (`.apk`), Windows (`.exe`), or Linux builds, verifies SHA-256 checksums, copies outputs to Google Drive, flushes FUSE (`drive.flush_and_unmount()`), and stops the session. |
| [utils/colab-rclone.sh](utils/colab-rclone.sh) | `make run-colab-rclone` | Optional, disabled-by-default helper to configure (`--enable`) or remove (`--disable`) `rclone` Google Drive access on an active Colab SSH VM. Requires explicit user permission (`--enable` / `ENABLE_COLAB_RCLONE=1` + interactive `YES` confirmation) before copying `rclone.conf`. |
| [utils/gh-release-upload-resilient.sh](utils/gh-release-upload-resilient.sh) | `make run-gh-release-upload-resilient` | Sequential GitHub Release asset uploader hardened for slow/unstable connections: uses `curl` over HTTP/1.1 with keepalive, no total timeout, stall detection (`--speed-limit`/`--speed-time`), automatic cleanup of partial `starter` assets, retries with backoff, optional `--status-file`, and post-upload byte-size verification. |

---

> Add new scripts to the table above. The `run-<name>` target is auto-generated — no Makefile edit needed.
