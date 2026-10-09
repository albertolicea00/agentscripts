# scripts/

Local shell scripts organized by category, with VPS sync tooling in `.sync-vps/`.

```
scripts/
├── .colab-connect/         # Google Colab SSH bridge & remote execution (Cloudflare Tunnel)
├── .sync-vps/              # VPS ↔ local sync (rsync over SSH)
└── downloads/
    ├── dl-romsfun-batch.sh # Download retro/PSP ROMs from romsfun.com in batch from file or URL list
    ├── dl-tubi.sh          # Download Tubi progressive MP4 from M3U8 Detector JSON
    └── hls-local.sh        # Download HLS or direct streams locally (requires ffmpeg)
```

## Usage

```bash
make help                 # list all commands (sync + scripts)
make run-dl-romsfun-batch # run scripts/downloads/dl-romsfun-batch.sh
make run-dl-tubi          # run scripts/downloads/dl-tubi.sh
make run-hls-local        # run scripts/downloads/hls-local.sh

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
| [downloads/dl-romsfun-batch.sh](downloads/dl-romsfun-batch.sh) | `make run-dl-romsfun-batch` | Downloads retro/PSP ROMs from romsfun.com in batch from file or URL list. Handles Cloudflare, dynamic CDN tokens, resume, and extraction. |
| [downloads/dl-tubi.sh](downloads/dl-tubi.sh) | `make run-dl-tubi` | Downloads Tubi progressive MP4 from an M3U8 Detector JSON export. Dedupes repeated segment URLs (single file, not real HLS chunks). |
| [downloads/hls-local.sh](downloads/hls-local.sh) | `make run-hls-local` | Downloads HLS or direct video streams from M3U8 Detector JSON. Requires `curl` and `ffmpeg`. |

---

> Add new scripts to the table above. The `run-<name>` target is auto-generated — no Makefile edit needed.
