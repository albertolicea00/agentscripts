# Agent Guidelines

Instructions for AI agents working in this repository.

## Repository Purpose

Google Colab notebooks organized by category under `src/`, plus `sync/` scripts for Drive ↔ GitHub synchronization.

## Structure Rules

- **All notebooks go under `src/<category>/`** — never at the repo root or directly in `src/`.
- Category names are lowercase, hyphen-separated: `downloads`, `data-processing`, `ml-training`, etc.
- Sync scripts live in `sync/` — two Colab notebooks (`.ipynb`) and two shell scripts (`.sh`).
- Helper Python/shell scripts live in `scripts/`.

## When Adding a Notebook

1. Place it at `src/<appropriate-category>/<descriptive-name>.ipynb`.
2. Add an entry to `docs/NOTEBOOKS.md` under the correct category section.
3. Add an entry to `CHANGELOG.md` under today's date.
4. If it came from `TODO.md`, check off or remove that item.

## Notebook Conventions

- First cell: `!pip install` dependencies only.
- Second cell: constants and configuration (URLs, paths, toggles).
- Last cell (optional): mount Drive and copy output there.
- Use `cloudscraper` for sites with Cloudflare protection.
- Output goes to `/content/<category>/` inside Colab, never committed.

## Sync Scripts (`sync/`)

Two interfaces, same operation:

| Script | Auth | When to use |
|---|---|---|
| `pull.ipynb` | OAuth (interactive) | Running inside Colab |
| `push.ipynb` | OAuth (interactive) | Running inside Colab |
| `pull.sh` | Service account JSON | Local machine / CI |
| `push.sh` | Service account JSON | Local machine / CI |

- Credentials never committed — configure via `sync/.env` (copy from `sync/.env.example`).
- Run via `make pull` / `make push` (shell) or `make pull-colab` / `make push-colab` (opens Colab in browser).

## What Not to Commit

- Downloaded binaries (`.iso`, `.zip`, `.rar`, etc.) — gitignored.
- OAuth tokens or service account keys — gitignored.
- Notebook outputs (`.ipynb_checkpoints`) — gitignored.

## TODO.md

Informal backlog — ideas, notebooks to add, improvements. No structure required. Drop things here as they come up; clean up when done.

## CHANGELOG Format

```
## YYYY-MM-DD
- Added: `src/<category>/<file>.ipynb` — short description
- Fixed: <what>
- Changed: <what>
```
