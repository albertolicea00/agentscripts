# notebooks/ — Agent Guidelines

Scoped rules for AI agents working inside `notebooks/`.

## Rules

- Notebooks go under `notebooks/<category>/<name>.ipynb`. Never at `notebooks/` root.
- Category names: lowercase, hyphen-separated (`downloads`, `data-processing`, `ml-training`).
- Sync scripts live in `.sync-colab/` — do not move them.

## When Adding a Notebook

1. Place at `notebooks/<category>/<name>.ipynb`.
2. Add a row to `notebooks/README.md` under the correct category.
3. Add an `open-<name>` target to `notebooks/Makefile`.
4. Add a forwarding entry for it in the root `Makefile`.
5. Update `CHANGELOG.md`.

## Notebook Structure (cell order)

1. `!pip install` — deps only, no logic
2. Markdown header cell — full doc (see root `AGENTS.md` for template)
3. UI widget cell — collects user input (empty by default, never hardcoded)
4. Setup cell — reads widget values, initializes clients/paths
5. Logic cells — functions, processing
6. Run cell — executes against collected input
7. Drive copy cell — required, copies to `CollabMedia/<category>/<name>/`

## Sync (.sync-colab/)

Do not edit sync scripts unless the user explicitly asks. Config goes in `.sync-colab/.env` (gitignored). Template is `.sync-colab/.env.example` (tracked).
