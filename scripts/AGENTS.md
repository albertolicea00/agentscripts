# scripts/ — Agent Guidelines

Scoped rules for AI agents working inside `scripts/`.

## Rules

- Scripts go under `scripts/<category>/<name>.sh`. Never at `scripts/` root.
- Category names: lowercase, hyphen-separated (`downloads`, `processing`, `utils`).
- Sync directories (`.sync-vps/`, any future `.sync-*/`) live at `scripts/` root — excluded from script auto-discovery and `run-*` targets.
- Every script must be executable (`chmod +x`).

## When Adding a Script

1. Place at `scripts/<category>/<name>.sh`.
2. Make executable: `chmod +x scripts/<category>/<name>.sh`.
3. First non-shebang line must be `# <short description>` — this is shown in `make help`.
4. Add a row to `scripts/README.md`.
5. Update `CHANGELOG.md`. The `run-<name>` Make target is auto-discovered — no Makefile edit needed.

## Script Structure

```bash
#!/usr/bin/env bash
# <Short one-line description shown in make help>
# Usage: ./script.sh [args]

set -euo pipefail

# check deps
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg required"; exit 1; }

# config via env or args, never hardcoded
OUT_DIR="${OUT_DIR:-$HOME/Downloads}"
```

## What Not to Hardcode

- Output paths — use env vars or `$HOME/Downloads` as default
- Credentials — read from env or `.env` file
- URLs — accept as positional args or from a JSON file passed as arg
