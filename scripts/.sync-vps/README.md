# .sync-vps/

Sync scripts to keep `scripts/` in sync with a remote VPS via rsync over SSH.

| Script | What it does |
|---|---|
| `pull.sh` | VPS → local `scripts/` |
| `push.sh` | local `scripts/` → VPS |

```bash
make setup-vps    # create .sync-vps/.env from template
make pull-vps     # VPS → local
make push-vps     # local → VPS
```

---

## Setup

```bash
make setup-vps
# then edit scripts/.sync-vps/.env:
```

| Var | Description |
|---|---|
| `VPS_HOST` | IP or hostname of VPS |
| `VPS_USER` | SSH user |
| `VPS_PORT` | SSH port (default: 22) |
| `VPS_SCRIPTS_PATH` | Absolute path on VPS where scripts live |
| `SSH_KEY` | Path to SSH private key (default: `~/.ssh/id_rsa`) |

---

## Files

| File | Purpose |
|---|---|
| `.env.example` | Config template — tracked in git |
| `.env` | Your credentials — gitignored, never commit |
