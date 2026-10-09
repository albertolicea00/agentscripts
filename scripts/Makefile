.PHONY: help setup-vps pull-vps push-vps setup-colab connect-colab run-colab

SYNC_VPS   = .sync-vps
ENV_VPS    = $(SYNC_VPS)/.env
COLAB_CONN = .colab-connect
ENV_COLAB  = $(COLAB_CONN)/.env

# Auto-discover all .sh files (excluding hidden dirs like .sync-vps, .colab-connect)
SCRIPTS := $(shell find . -name "*.sh" -not -path "*/\.*" | sed 's|^\./||' | sort)

help:
	@echo ""
	@echo "  Sync (.sync-vps)"
	@printf "    \033[36m%-28s\033[0m %s\n" "setup-vps" "Copy .env.example → .sync-vps/.env"
	@printf "    \033[36m%-28s\033[0m %s\n" "pull-vps"  "Pull scripts from VPS → local"
	@printf "    \033[36m%-28s\033[0m %s\n" "push-vps"  "Push local scripts → VPS"
	@echo ""
	@echo "  Colab Connect (.colab-connect)"
	@printf "    \033[36m%-28s\033[0m %s\n" "setup-colab"   "Setup SSH keys & cloudflared for Colab"
	@printf "    \033[36m%-28s\033[0m %s\n" "connect-colab" "Connect to active Colab instance via SSH"
	@echo ""
	@echo "  Scripts"
	@if [ -z "$(SCRIPTS)" ]; then \
		echo "    (none yet)"; \
	else \
		for s in $(SCRIPTS); do \
			name=$$(basename "$$s" .sh); \
			dir=$$(dirname "$$s" | sed 's|^\./||'); \
			desc=$$(grep -m1 '^#[^!]' "$$s" 2>/dev/null | sed 's/^# *//; s/ *$$//'); \
			[ -z "$$desc" ] && desc="(no description)"; \
			printf "    \033[36mrun-%-24s\033[0m \033[90m%s/\033[0m %s\n" "$$name" "$$dir" "$$desc"; \
		done; \
	fi

# ── VPS sync ─────────────────────────────────────────────────────────────────

setup-vps:
	@if [ -f $(ENV_VPS) ]; then \
		echo ".sync-vps/.env already exists — skipping."; \
	else \
		cp $(SYNC_VPS)/.env.example $(ENV_VPS); \
		echo "Created $(ENV_VPS) — fill in VPS details before running pull-vps/push-vps."; \
	fi

pull-vps:
	@bash $(SYNC_VPS)/pull.sh

push-vps:
	@bash $(SYNC_VPS)/push.sh

# ── Colab connect ────────────────────────────────────────────────────────────

setup-colab:
	@bash $(COLAB_CONN)/setup.sh

connect-colab:
	@bash $(COLAB_CONN)/connect.sh

run-colab:
	@bash $(COLAB_CONN)/run.sh $(CMD)

# ── Dynamic script runner ─────────────────────────────────────────────────────

run-%:
	@script=$$(find . -name "$*.sh" -not -path "*/\.*" | head -1); \
	if [ -z "$$script" ]; then \
		echo "No script named '$*.sh' found under scripts/"; exit 1; \
	fi; \
	echo "Running: $$script"; \
	bash "$$script"
