# sync/

Scripts to keep Drive and GitHub in sync — pull notebooks from Drive into `src/`, push `src/` back to Drive.

Two interfaces for the same operations:

| Script | Auth method | Where it runs |
|---|---|---|
| `pull.ipynb` | Colab OAuth + Secrets | Google Colab |
| `push.ipynb` | Colab OAuth + Secrets | Google Colab |
| `pull.sh` | Service account JSON | Local machine / CI |
| `push.sh` | Service account JSON | Local machine / CI |

---

## Colab notebooks (`pull.ipynb`, `push.ipynb`)

**Auth:** Google OAuth (Colab handles it via `auth.authenticate_user()`).  
**Config:** Colab Secrets — open the 🔑 panel on the left and add:

| Key | Value |
|---|---|
| `DRIVE_FOLDER_ID` | ID from Drive URL: `drive.google.com/drive/folders/<ID>` |
| `GITHUB_TOKEN` | GitHub PAT with `repo` scope |
| `GITHUB_USER` | `albertolicea00` |
| `GITHUB_REPO` | `collab-notbooks` |

Open in Colab via:
```
make pull-colab   # opens pull.ipynb
make push-colab   # opens push.ipynb
```

---

## Shell scripts (`pull.sh`, `push.sh`)

**Auth:** Google service account JSON.  
**Config:** `sync/.env` (copy from `sync/.env.example`):

```bash
make setup   # copies .env.example → sync/.env
# then edit sync/.env and fill in your values
```

Run:
```bash
make pull    # runs pull.sh
make push    # runs push.sh
```

**Service account requirements:**
- Drive API enabled on the GCP project.
- Account has at least `roles/drive.file` on the target folder (or share the folder with the service account email).

---

## Files

| File | Purpose |
|---|---|
| `.env.example` | Template for local config — tracked in git |
| `.env` | Your actual credentials — gitignored, never commit |
| `service_account.json` | GCP service account key — gitignored, never commit |
