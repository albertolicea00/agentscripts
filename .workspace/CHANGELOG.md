# Changelog

Repo-level changes only — structure, tooling, Makefiles, AGENTS, docs.
**Notebook changes → `notebooks/CHANGELOG.md`. Script changes → `scripts/CHANGELOG.md`.**

Format: `Added | Changed | Fixed | Removed` under each date.

---

## 2026-10-09

- Added: root Makefile forwarding targets for `open-colab-connect`, `setup-colab`, `connect-colab`, and `run-colab`.
- Changed: root `README.md` updated with Colab Connect commands and documentation.

## 2026-10-06

- Changed: migrated to `notebooks/` + `scripts/` two-area structure (`src/` and `sync/` removed)
- Added: hierarchical Makefile system — root delegates to `notebooks/Makefile` and `scripts/Makefile`
- Added: scoped `.gitignore` files per area (`notebooks/`, `scripts/`)
- Added: `scripts/.sync-vps/` — VPS rsync sync tooling
- Added: `AGENTS.md`, `README.md` rewritten for new structure
- Added: three-changelog system (`notebooks/CHANGELOG.md`, `scripts/CHANGELOG.md`, root)
