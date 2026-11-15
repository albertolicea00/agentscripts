# Google Colab Runtime Limits & Account Plan Notes

Reference documentation for the Google Colab account and runtime behavior observed with `colab-archive-dl.sh` and `colab` CLI.

## Observed Account Plan

Checked via `colab usage`:

- **Plan tier:** Google Colab **Free tier** (`0.00 compute units` balance).
- **Default hardware:** Standard CPU VM (`Shape: Standard`, `Variant: DEFAULT`).
- **Nominal burn rate:** `0.08 compute units/hr` (informational; no compute units are deducted on the free tier).
- **Local ephemeral disk (`/content/`):** `~108 GiB` overlay.
- **Persistent storage (`/content/drive`):** Google Drive (~`1.9 TiB` total capacity on the connected account).

## VM Lifetimes, Idle Timeouts & Resets

Per Google Colab's official FAQ (`research.google.com/colaboratory/faq.html`):

1. **Maximum VM lifetime (~12 hours):**
   - Free-tier VMs have a maximum continuous lifetime of up to **12 hours** (exact duration can fluctuate based on platform load).
   - When the lifetime cap is reached, the VM is recycled and **everything in `/content/` is wiped**.
   - Paid plans with active Compute Units (Pay As You Go, Colab Pro, Colab Pro+) support longer runtimes (up to 24 hours for background execution) and priority hardware; once Compute Units reach `0.00` (or expire after 90 days), the account reverts to free-tier limits.

2. **Idle timeouts:**
   - Colab disconnects VMs that remain idle for too long without active execution or interaction.
   - Keeping an active foreground command running over `colab ssh` (e.g., `aria2c` + Drive copy progress output with `ServerAliveInterval=30`) prevents idle disconnection.

3. **Dynamic quotas & resets (no fixed schedule):**
   - Google **does not publish fixed static limits or a fixed daily reset clock** for free-tier usage.
   - Availability and session caps scale dynamically with global demand and recent account usage. Heavy continuous usage can result in temporary cooldowns or stricter session lifetimes until usage subsides.

## Practical Impact on Long Downloads (`colab-archive-dl.sh`)

- **Resumable across VM resets:** Verified files are written to `/content/drive/MyDrive/CollabMedia/...`. If a VM hits the 12-hour cap or disconnects, re-running `colab-archive-dl.sh` after creating a new session (`colab new -s colab && colab drivemount -s colab`) skips already-verified files on Drive.
- **Ephemeral `/content/` safety:** Local files in `/content/` are deleted immediately after Drive copy and SHA-1 verification so the `108 GiB` overlay does not fill up.
- **Single SSH tunnel:** Colab allows only one active `colab ssh` connection per runtime at a time (`HTTP 429` if a second connection opens before the first closes).
