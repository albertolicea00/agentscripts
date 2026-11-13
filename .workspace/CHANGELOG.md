# Changelog

Repo-level changes only — structure, tooling, Makefiles, AGENTS, docs.
**Notebook changes → `notebooks/CHANGELOG.md`. Script changes → `scripts/CHANGELOG.md`.**

Format: `Added | Changed | Fixed | Removed` under each date.

---

## 2026-11-13

- Changed: `README.md` — documented official Colab CLI `ssh` subcommand usage, `ProxyCommand` integration, and `~/.ssh/config` setup.

## 2026-11-11

- Changed: `AGENTS.md` — clarify that co-author attribution is mandatory, while each identity applies only to the assistant that actually contributed.

- Changed: `AGENTS.md` — require English for repository content and commit messages, and require AI-assisted commits to identify the actual contributing assistant with its verified co-author trailer (Codex: `Codex <noreply@openai.com>`); forbid attribution to another assistant or invented or unverified identities.

- Added: root `Makefile` forwarding target `open-archive-torrents`.

## 2026-10-09

- Changed: `AGENTS.md` commit attribution guidelines updated to use `gemini-code-assist-user` and forbid `<antigravity@google.com>`.
- Added: root Makefile forwarding targets for `open-colab-connect`, `setup-colab`, `connect-colab`, and `run-colab`.
- Changed: root `README.md` updated with Colab Connect commands and documentation.

## 2026-10-06

- Changed: migrated to `notebooks/` + `scripts/` two-area structure (`src/` and `sync/` removed)
- Added: hierarchical Makefile system — root delegates to `notebooks/Makefile` and `scripts/Makefile`
- Added: scoped `.gitignore` files per area (`notebooks/`, `scripts/`)
- Added: `scripts/.sync-vps/` — VPS rsync sync tooling
- Added: `AGENTS.md`, `README.md` rewritten for new structure
- Added: three-changelog system (`notebooks/CHANGELOG.md`, `scripts/CHANGELOG.md`, root)
