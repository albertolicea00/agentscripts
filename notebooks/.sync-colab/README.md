# .sync-colab/

Sync scripts to keep `notebooks/` and Google Drive in sync.

Two interfaces for the same operations:

| Script | Auth method | Where it runs |
|---|---|---|
| `pull.ipynb` | Colab OAuth + Secrets | Google Colab |
| `push.ipynb` | Colab OAuth + Secrets | Google Colab |
| `pull.sh` | Service account JSON | Local machine / CI |
| `push.sh` | Service account JSON | Local machine / CI |

Run via root or `notebooks/` Makefile — don't call scripts directly unless debugging.

---

## Colab notebooks (`pull.ipynb`, `push.ipynb`)

**Auth:** Google OAuth (`auth.authenticate_user()`).  
**Config:** Colab Secrets — open the 🔑 panel on the left and add:

| Key | Value |
|---|---|
| `DRIVE_FOLDER_ID` | From Drive URL: `drive.google.com/drive/folders/<ID>` |
| `GITHUB_TOKEN` | GitHub PAT with `repo` scope |
| `GITHUB_USER` | `albertolicea00` |
| `GITHUB_REPO` | `agentscripts` |

```bash
make pull-colab    # opens pull.ipynb in Colab
make push-colab    # opens push.ipynb in Colab
```

---

## Shell scripts (`pull.sh`, `push.sh`)

**Auth:** Google service account JSON.  
**Config:** `.sync-colab/.env` (copy from `.env.example`):

```bash
make setup    # creates .sync-colab/.env from .env.example
# fill in values, then:
make pull
make push
```

**Service account requirements:**
- Drive API enabled on the GCP project.
- Account has at least `roles/drive.file` on the target folder (or share the folder directly with the service account email).

---

## Files

| File | Purpose |
|---|---|
| `.env.example` | Config template — tracked in git |
| `.env` | Your credentials — gitignored, never commit |
| `service_account.json` | GCP key — gitignored, never commit |
