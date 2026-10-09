# notebooks/

Google Colab notebooks organized by category.

```
notebooks/
├── .sync-colab/          # Drive ↔ GitHub sync scripts
├── downloads/            # Scrapers and batch downloaders
└── <category>/           # Add folders as needed
```

Run `make help` from repo root or this folder to see all commands.

---

## downloads

| Notebook | Open | Description |
|---|---|---|
| [downloads/romsfun.ipynb](downloads/romsfun.ipynb) | `make open-romsfun` | Scrape and download PSP ROM ISOs from romsfun.com. Bypasses Cloudflare via `cloudscraper`. Output → `CollabMedia/downloads/romsfun/`. |
| [downloads/hls-colab.ipynb](downloads/hls-colab.ipynb) | `make open-hls` | Download HLS/obfuscated streams (TikTok CDN, standard m3u8, direct MP4). Accepts M3U8 Detector JSON. Output → `CollabMedia/downloads/hls-colab/`. |
| [downloads/ytdlp-2drive.ipynb](downloads/ytdlp-2drive.ipynb) | `make open-ytdlp` | yt-dlp + EJS/PO-token solver. Requires `cookies.txt`. Output → `CollabMedia/downloads/ytdlp-2drive/`. |

---

## utils

| Notebook | Open | Description |
|---|---|---|
| [utils/colab-connect.ipynb](utils/colab-connect.ipynb) | `make open-colab-connect` | OpenSSH daemon + Cloudflare Tunnel bridge for remote SSH & command execution. Output → `CollabMedia/utils/colab-connect/session.json`. |

---

## .sync-colab

Sync tooling to keep this repo and Google Drive in sync. See [.sync-colab/README.md](.sync-colab/README.md).

| Command | What it does |
|---|---|
| `make setup` | Create `.sync-colab/.env` from template |
| `make pull` | Drive → repo (shell, service account) |
| `make push` | repo → Drive (shell, service account) |
| `make pull-colab` | Open pull notebook in Colab (OAuth) |
| `make push-colab` | Open push notebook in Colab (OAuth) |

---

> Add new notebooks to the table above when you add them here. See root `AGENTS.md` for conventions.
