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
- **Transient SSH bridge drops (`exit 255`):** Even with `ServerAliveInterval=30`, Colab's WebSocket SSH bridge or brief local DNS/network hiccups can trigger `Timeout, server colab not responding` (`exit 255`) while the Colab VM itself remains `IDLE`. Always check `colab status` before creating a new VM.
- **Retry current collection instead of skipping ahead:** When downloading multiple Archive.org items, **do not** loop across items with `|| continue` (which skips an unfinished collection on `exit 255` and can stall on `HTTP 429` if the previous tunnel is still closing). Run one collection at a time with a retry loop and a short cooldown (e.g., `sleep 10`) until it exits `0` before moving to the next collection:
  ```bash
  for attempt in 1 2 3 4 5; do
    ./scripts/downloads/colab-archive-dl.sh -e nsp,xci <item> && break
    sleep 10
  done
  ```
- **Archive.org per-item throttling:** While Colab can download at `25–54 MiB/s` from fast Archive.org datanodes, Archive.org throttles certain items/nodes to `~6–8 MiB/s` even with `aria2c --split=8`.

