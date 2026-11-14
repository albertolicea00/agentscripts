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

**Colab SSH & Remote Execution (Cloudflare Tunnel bridge):**
```bash
make setup-colab         # first-time: check cloudflared & copy SSH public key
make connect-colab       # interactive SSH connection to Colab runtime
```

## Connect via SSH (Colab CLI)

Use the official `google-colab-cli` (`colab ssh`) for direct WebSocket-based SSH access without needing Cloudflare Tunnel:

- **Install & authenticate:**
  ```bash
  uv tool install google-colab-cli   # or: pip install google-colab-cli
  colab usage                        # completes browser OAuth login
  ```

- **SSH key requirement (important):**
  Colab SSH **rejects RSA keys (`ssh-rsa`)**. Generate an Ed25519 key (used by default):
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
  ```

- **Direct interactive shell / named session:**
  ```bash
  colab new -s colab                 # creates runtime with both Jupyter kernel + SSH
  colab ssh -s colab
  ```

- **OpenSSH `ProxyCommand` integration (e.g., IDE remote development):**
  ```bash
  ssh -o ProxyCommand="colab ssh --proxy-mode -s my-session" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@colab-runtime
  ```

- **`~/.ssh/config` (use the full `colab` path for IDEs/non-login shells):**
  ```sshconfig
  Host colab
    User root
    IdentityFile ~/.ssh/id_ed25519
    ProxyCommand ~/.local/bin/colab ssh --proxy-mode -s colab
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
  ```

- **Operational notes:**
  - **One SSH session at a time:** Colab returns `HTTP 429` if a second `colab ssh` connects while another is active.
  - **Mount Drive before long tasks:** `colab drivemount -s colab /content/drive` uses the Jupyter kernel API and prompts for browser OAuth; run it before starting downloads so files can be copied immediately.
  - **Idle/reclaimed runtimes:** If `ssh colab` or `colab drivemount` returns `HTTP 404`, the runtime was reclaimed or created without a kernel — run `colab new -s colab` to provision a fresh one.
  - **Archive.org over HTTPS vs Torrent:** Direct HTTPS with `aria2c --split=8` reaches ~30–130+ MiB/s on Colab, whereas Archive.org torrents can stall at ~99% on `.____padding_file/*` entries (`Invalid range header`). Use `make run-colab-archive-dl` or select **HTTPS only** in `archive-torrents.ipynb`.

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

- [**albertolicea00/agentsconfig**](https://github.com/albertolicea00/agentsconfig) — global Git security hooks, AI agent configurations, and skill lockfiles.
- [**albertolicea00/agentskills**](https://github.com/albertolicea00/agentskills) — my collection of agent skills.
- [**albertolicea00/clawflows**](https://github.com/albertolicea00/clawflows) — the workflow half of this setup: ready-to-use OpenClaw workflows for multi-step tasks you can fire from a chat app. *code, vibe, repeat...*

## License

[Unlicense](UNLICENSE) — Powered by @albertolicea00 and his unstoppable AI‑agents

> 🤖 Many of these notebooks and scripts are **AI‑generated** and then reviewed & refined by me. The AI proposes, I approve — everything passes through manual review before being used.
