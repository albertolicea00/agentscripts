<!-- # >> agentscripts -->

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="ascii-art-text-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="ascii-art-text-light.png">
  <img alt="clawflows" src="ascii-art-text-light.png">
  <!-- Credits to [patorjk.com TAAG](https://patorjk.com/software/taag/#p=display&f=Big+Money-sw&t=scripts&x=none&v=4&h=0&w=80&we=false) for the `ascii-art-text`, font `Big Money-sw`. -->
</picture>

My personal collection of Google Colab notebooks and local shell scripts — the ones I actually use.  
Download things, process media, automate tasks. *code, vibe, repeat...*

![Google Colab](https://img.shields.io/badge/Google-Colab-F9AB00?logo=googlecolab&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-Scripts-4EAA25?logo=gnubash&logoColor=white)


## See the [notebooks](notebooks/README.md)

## See the [scripts](scripts/README.md)

## What is this?

Two areas:

- **`notebooks/`** — Google Colab notebooks organized by category. Each one has a widget UI for input (no hardcoded values), downloads to `/content/`, and copies output to `MyDrive/CollabMedia/` on Drive.
- **`scripts/`** — Local shell scripts organized by category, runnable via `make run-<name>`. Auto-discovered — no Makefile edits needed when adding new ones.

Each area has its own sync tooling: notebooks sync with Google Drive via `.sync-colab/`, scripts sync with a VPS via `.sync-vps/`.

## Usage

```bash
make help            # list all commands
```

**Open a notebook in Colab:**
```bash
make open-romsfun        # PSP ROM downloader
make open-hls            # HLS / obfuscated stream downloader
make open-ytdlp          # yt-dlp video downloader
make open-colab-connect  # SSH bridge notebook for remote connection
```

**Run a local script:**
```bash
make run-hls-local       # HLS stream → local MP4 (requires ffmpeg)
make run-dl-tubi         # Tubi progressive MP4 downloader
```

**Colab SSH & Remote Execution:**
```bash
make setup-colab         # first-time: check cloudflared & copy SSH public key
make connect-colab       # interactive SSH connection to Colab runtime
```

**Sync:**
```bash
make setup               # first-time: create notebooks/.sync-colab/.env
make pull                # Drive → repo
make push                # repo → Drive
make setup-vps           # first-time: create scripts/.sync-vps/.env
make pull-vps            # VPS → local scripts/
make push-vps            # local scripts/ → VPS
```


## Related repos

- [**albertolicea00/agentskills**](https://github.com/albertolicea00/agentskills) — my collection of agent skills.
- [**albertolicea00/clawflows**](https://github.com/albertolicea00/clawflows) — the workflow half of this setup: ready-to-use OpenClaw workflows for multi-step tasks you can fire from a chat app. *code, vibe, repeat...*

## License

[Unlicense](UNLICENSE) — Powered by @albertolicea00 and his unstoppable AI‑agents

> 🤖 Many of these notebooks and scripts are **AI‑generated** and then reviewed & refined by me. The AI proposes, I approve — everything passes through manual review before being used.
