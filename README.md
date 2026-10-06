# collab-notebooks

Collection of Google Colab notebooks organized by category, with sync tooling to keep Drive and GitHub in sync.

## Structure

```
collab-notebooks/
├── src/                    # Notebooks, grouped by category
│   ├── downloads/          # Scrapers and batch downloaders
│   └── <category>/         # Add folders as needed
├── sync/                   # Drive ↔ GitHub sync scripts
├── scripts/                # Helper CLI scripts
├── docs/
│   └── NOTEBOOKS.md        # Index of all available notebooks
├── TODO.md                 # Informal backlog — ideas and things to add
└── CHANGELOG.md            # Change history
```

### `src/`

Every notebook lives under `src/<category>/`. Category is whatever makes sense for the task — `downloads`, `media`, `data`, `ml`, etc.

### `sync/`

Scripts to pull notebooks from Google Drive into this repo and push local changes back up. Run these to stay in sync without doing it by hand.

| Script | Auth | Purpose |
|---|---|---|
| `sync/pull.ipynb` | OAuth (Colab) | Download Drive notebooks → `src/` |
| `sync/push.ipynb` | OAuth (Colab) | Upload `src/` notebooks → Drive |
| `sync/pull.sh` | Service account | Same, runs locally / CI (`make pull`) |
| `sync/push.sh` | Service account | Same, runs locally / CI (`make push`) |

### `scripts/`

Standalone Python/shell scripts that support the notebooks (not notebooks themselves).

## Quickstart

1. Open any notebook from `src/` in Google Colab.
2. Run all cells top to bottom.
3. Optional last cell: mount Drive and copy output there.

## Sync

Two options:
- **Colab** (OAuth): open `sync/pull.ipynb` or `sync/push.ipynb` in Colab and run.
- **Local / CI** (service account): `make pull` or `make push`. Copy `sync/.env.example` → `sync/.env` and set credentials first (`make setup`).

## Notebooks

See [docs/NOTEBOOKS.md](docs/NOTEBOOKS.md) for the full index.

## Backlog

Ideas and notebooks to add live in [TODO.md](TODO.md). Drop things there as they come up.
