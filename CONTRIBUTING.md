# Contributing

> **Note:** This is not an open-contribution project. This guide exists as a personal reference so I (and my AI agents) know how to keep things organized.

If you want the scripts — fork it. [MIT license](LICENSE). Take everything.

## Adding a Notebook

1. Place at `notebooks/<category>/<name>.ipynb`
2. Second cell must be a markdown header — see [AGENTS.md](AGENTS.md) for the required template
3. No hardcoded input — widgets only. Drive output required (last cell → `MyDrive/CollabMedia/`)
4. Add row to `notebooks/README.md`
5. Add `open-<name>` target to `notebooks/Makefile` and forward it from root `Makefile`
6. Update `notebooks/CHANGELOG.md`

## Adding a Script

1. Place at `scripts/<category>/<name>.sh`, make it executable
2. Line 2 must be `# <short description>` — shown in `make help`
3. Add row to `scripts/README.md`
4. Update `scripts/CHANGELOG.md`
5. No Makefile edit needed — `run-<name>` is auto-discovered

## Conventions

- No hardcoded credentials, paths, or URLs anywhere
- Output goes to `MyDrive/CollabMedia/` (notebooks) or `scripts/output/` (scripts)
- `set -euo pipefail` on every shell script
- Deps checked at top with clear error messages

## Checklist

- [ ] Correct folder and filename
- [ ] Markdown header cell present (notebooks) or description comment (scripts)
- [ ] No hardcoded user input
- [ ] README row added
- [ ] Changelog updated
- [ ] Tested (notebook ran end-to-end, script exits cleanly)
