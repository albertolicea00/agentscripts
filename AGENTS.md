# Agent Guidelines

Instructions for AI agents working in this repository.

## Repository Purpose

`agentscripts` holds two kinds of automation:
- **`notebooks/`** — Google Colab notebooks, organized by category, with Drive sync tooling in `.sync-colab/`
- **`scripts/`** — Local shell scripts, organized by category, runnable via `make run-<name>`

## Structure

```
agentscripts/
├── notebooks/
│   ├── .sync-colab/          # Drive ↔ GitHub sync (ipynb + sh)
│   ├── downloads/            # Download notebooks
│   └── <category>/
├── scripts/
│   ├── .sync-vps/            # VPS ↔ local sync (rsync over SSH)
│   ├── downloads/            # Download shell scripts
│   └── <category>/
├── AGENTS.md                 # This file
├── .workspace/CHANGELOG.md   # repo-level changelog (not notebooks/scripts)
├── TODO.md
└── Makefile                  # Delegates to notebooks/ and scripts/ Makefiles
```

Each subfolder has its own `AGENTS.md`, `README.md`, and `Makefile` scoped to that area.

## When Adding a Notebook

1. Place at `notebooks/<category>/<name>.ipynb`.
2. Add a row to `notebooks/README.md` under the correct category.
3. Add an `open-<name>` target to `notebooks/Makefile` and a forwarding entry in the root `Makefile`.
4. Add an entry to `notebooks/CHANGELOG.md` under today's date.
5. Check off or remove the item from `TODO.md` if applicable.

## When Adding a Script

1. Place at `scripts/<category>/<name>.sh`. Make it executable (`chmod +x`).
2. First non-shebang line must be a `# <short description>` comment — shown in `make help`.
3. Add a row to `scripts/README.md`.
4. Add an entry to `scripts/CHANGELOG.md`. The `run-<name>` target in `scripts/Makefile` is auto-generated — no Makefile edit needed.

## Notebook Conventions

### Required header (second cell, markdown)

```markdown
# <Title> — <one-line description>

<2–3 sentence summary.>

---

## Source
- **Site / tool:** <URL>
- **How to find input:** <what to paste in the widget>

## What it does
Numbered steps end to end.

## How to use
Numbered cell-by-cell instructions.

## Known limitations
Silent failures, Colab gotchas, rate limits, etc.

## Output
Folder tree showing Drive destination.
```

### Rules

- **No hardcoded user input.** URLs, IDs, file paths → `ipywidgets.Textarea` / `ipywidgets.Text`. Widget starts empty.
- **Drive output required** (last cell): copy to `MyDrive/CollabMedia/<category>/<notebook-name>/`.
- Colab temp output to `/content/<category>/<notebook-name>/`.
- Use `cloudscraper` for Cloudflare-protected sites.
- Widget pattern:
  ```python
  import ipywidgets as widgets
  from IPython.display import display
  box = widgets.Textarea(value="", placeholder="One per line",
                         layout=widgets.Layout(width="100%", height="200px"))
  display(widgets.Label("Label:"), box)
  # next cell:
  items = [x.strip() for x in box.value.splitlines() if x.strip()]
  ```

### Drive output structure

```
MyDrive/CollabMedia/
├── downloads/
│   ├── romsfun/         ← notebooks/downloads/romsfun.ipynb
│   ├── hls-colab/       ← notebooks/downloads/hls-colab.ipynb
│   └── ytdlp-2drive/    ← notebooks/downloads/ytdlp-2drive.ipynb
└── <category>/
    └── <notebook-name>/
```

## Script Conventions

- Shebang: `#!/usr/bin/env bash`
- Second line: `# <short description>` — appears in `make help`
- `set -euo pipefail` on the third line
- No hardcoded paths — use env vars or positional args
- Deps checked at top with clear error messages

## Sync

### `notebooks/.sync-colab/` — Drive ↔ GitHub

| Script | Auth | When |
|---|---|---|
| `pull.ipynb` | Colab OAuth | Inside Colab |
| `push.ipynb` | Colab OAuth | Inside Colab |
| `pull.sh` | Service account JSON | Local / CI |
| `push.sh` | Service account JSON | Local / CI |

Config via `notebooks/.sync-colab/.env` (copy from `.env.example`, run `make setup`).

### `scripts/.sync-vps/` — VPS ↔ local

| Script | What |
|---|---|
| `pull.sh` | VPS → local `scripts/` via rsync |
| `push.sh` | local `scripts/` → VPS via rsync |

Config via `scripts/.sync-vps/.env` (copy from `.env.example`, run `make setup-vps`).  
Requires SSH access and rsync on both ends.

## ⚠ CHANGELOG — UPDATE BEFORE EVERY COMMIT

There are **three** changelogs. Each tracks only its own area:

| File | Tracks |
|---|---|
| `notebooks/CHANGELOG.md` | Every notebook added, changed, or fixed |
| `scripts/CHANGELOG.md` | Every script added, changed, or fixed |
| `.workspace/CHANGELOG.md` | Repo-level changes only (structure, tooling, Makefiles, AGENTS) — NOT notebooks or scripts |

**Rule:** before staging anything under `notebooks/` → update `notebooks/CHANGELOG.md`. Before staging anything under `scripts/` → update `scripts/CHANGELOG.md`. Never put notebook/script entries in the root changelog.

Format (same in all three):

```
## YYYY-MM-DD
- Added: `<path>` — short description
- Changed: `<path>` — what changed and why
- Fixed: `<path>` — what was broken
- Removed: `<path>` — why removed
```

**No changelog entry = do not commit.** This is the most commonly skipped step.

## Commit attribution

Co-authoring with AI is allowed and encouraged. Add a `Co-Authored-By` trailer using your own model name, version, and vendor — do not copy anything from this file.

## TODO.md

Informal backlog. No structure required. Drop ideas, clean up when done.
