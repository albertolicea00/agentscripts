# agentscripts

Collection of Google Colab notebooks and local shell scripts, organized by category.

## Structure

```
agentscripts/
├── notebooks/                    # Google Colab notebooks
│   ├── .sync-colab/              # Drive ↔ GitHub sync scripts
│   ├── downloads/                # Scrapers and batch downloaders
│   └── <category>/               # Add folders as needed
├── scripts/                      # Local shell scripts
│   └── downloads/                # Local downloaders
├── TODO.md                       # Backlog
└── CHANGELOG.md                  # Change history
```

## Quickstart

```bash
make help          # list all commands from both notebooks/ and scripts/
```

### Open a notebook in Colab

```bash
make open-romsfun  # PSP ROM downloader
make open-hls      # HLS / obfuscated stream downloader
make open-ytdlp    # yt-dlp video downloader
```

### Run a local script

```bash
make run-hls-local   # HLS downloader (local, requires ffmpeg)
make run-dl-tubi     # Tubi progressive MP4 downloader
```

### Sync notebooks between Drive and GitHub

```bash
make setup         # first-time: create notebooks/.sync-colab/.env from template
make pull          # Drive → repo (shell, service account)
make push          # repo → Drive (shell, service account)
make pull-colab    # open pull notebook in Colab (OAuth)
make push-colab    # open push notebook in Colab (OAuth)
```

## Notebooks

See [notebooks/README.md](notebooks/README.md) for the full index.

## Scripts

See [scripts/README.md](scripts/README.md) for the full index.

## Backlog

[TODO.md](TODO.md) — drop ideas here as they come up.
