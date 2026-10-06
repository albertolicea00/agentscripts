# Notebooks Index

All available notebooks under `src/`, grouped by category.

---

## downloads

Batch downloaders and scrapers.

| Notebook | Description |
|---|---|
| [src/downloads/romsfun.ipynb](src/downloads/romsfun.ipynb) | Scrape and download PSP ROM ISOs from romsfun.com. Bypasses Cloudflare via `cloudscraper`. Output → `CollabMedia/downloads/romsfun/`. |
| [src/downloads/hls-colab.ipynb](src/downloads/hls-colab.ipynb) | Download obfuscated HLS streams (TikTok CDN PNG-wrapped segments, standard `.m3u8`, direct MP4). Accepts M3U8 Detector extension JSON. Output → `CollabMedia/downloads/hls-colab/`. |
| [src/downloads/ytdlp-2drive.ipynb](src/downloads/ytdlp-2drive.ipynb) | Download YouTube (and other sites) via yt-dlp + EJS/PO-token solver. Requires `cookies.txt`. Output → `CollabMedia/downloads/ytdlp-2drive/`. |

---

## sync

Drive ↔ GitHub sync tooling.

| Notebook | Description |
|---|---|
| `sync/pull.ipynb` | Download notebooks from configured Google Drive folder into `src/`. |
| `sync/push.ipynb` | Upload local `src/` notebooks back to Google Drive. |

---

> Add new notebooks here when you add them to `src/`. One row per notebook, short description, relative path link.
