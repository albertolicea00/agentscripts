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

### Required header (second cell, markdown)

Every notebook must have a markdown cell immediately after `pip install` with this structure:

```markdown
# <Notebook Title> — <one-line description>

<2–3 sentence summary of what it does.>

---

## Source

- **Site:** <URL of the site being scraped/used>
- **Section / category:** <where to find content on that site>
- **How to find URLs:** <explain what kind of URL the user should paste>

## What it does

Numbered list of steps the notebook performs, end to end.

## How to use

Numbered list of cells in order — what each one does and what the user must do between them.

## Known limitations

Anything that breaks silently, edge cases, Colab-specific gotchas (disconnect timeout, JS-rendered pages, rate limiting, etc.)

## Output

Folder tree showing where files land on Drive.
```

- **No hardcoded user input** — anything the user supplies (URLs, IDs, file paths) must go through a UI widget, not a hardcoded list. Use `ipywidgets.Textarea` for multi-line input, `ipywidgets.Text` for single values.
- Last cell: mount Drive and copy output to `CollabMedia/<category>/<notebook-name>/`. This cell is required, not optional.
- Colab temp output goes to `/content/<category>/<notebook-name>/` during the run.
- Use `cloudscraper` for sites with Cloudflare protection.

### Drive output structure

Mirrors `src/` exactly under `MyDrive/CollabMedia/`:

```
MyDrive/CollabMedia/
├── downloads/
│   └── romsfun/        ← output of src/downloads/romsfun.ipynb
└── <category>/
    └── <notebook-name>/
```

### UI widget pattern

```python
import ipywidgets as widgets
from IPython.display import display

input_box = widgets.Textarea(
    value="",
    placeholder="One item per line",
    layout=widgets.Layout(width="100%", height="200px"),
)
display(widgets.Label("Label:"), input_box)
```

Then in the next cell: `items = [x.strip() for x in input_box.value.splitlines() if x.strip()]`

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

**Updating CHANGELOG is mandatory** before every commit that adds or changes a notebook or script. No push without a CHANGELOG entry. If multiple files change in one commit, one entry per file is enough.

## Commit attribution

Co-authoring with AI is allowed and encouraged.
