.PHONY: help setup pull push pull-colab push-colab \
        open-romsfun open-hls open-ytdlp open-colab-connect

SYNC        = .sync-colab
ENV_FILE    = $(SYNC)/.env
COLAB_BASE  = https://colab.research.google.com/github/albertolicea00/agentscripts/blob/main/notebooks

help: ## Show notebook commands
	@echo ""
	@echo "  Sync (.sync-colab)"
	@grep -E '^(setup|pull|push|pull-colab|push-colab):.*##' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*##"}; {printf "    \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Open in Colab"
	@grep -E '^open-.*:.*##' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*##"}; {printf "    \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ── Sync ─────────────────────────────────────────────────────────────────────

setup: ## Copy .env.example → .sync-colab/.env (first-time setup)
	@if [ -f $(ENV_FILE) ]; then \
		echo ".sync-colab/.env already exists — skipping."; \
	else \
		cp $(SYNC)/.env.example $(ENV_FILE); \
		echo "Created $(ENV_FILE) — fill in your values before running pull/push."; \
	fi

pull: ## Pull notebooks from Drive (shell — requires .sync-colab/.env + service account)
	@bash $(SYNC)/pull.sh

push: ## Push notebooks to Drive (shell — requires .sync-colab/.env + service account)
	@bash $(SYNC)/push.sh

pull-colab: ## Open pull notebook in Colab (OAuth)
	@open "$(COLAB_BASE)/.sync-colab/pull.ipynb" 2>/dev/null \
	  || xdg-open "$(COLAB_BASE)/.sync-colab/pull.ipynb"

push-colab: ## Open push notebook in Colab (OAuth)
	@open "$(COLAB_BASE)/.sync-colab/push.ipynb" 2>/dev/null \
	  || xdg-open "$(COLAB_BASE)/.sync-colab/push.ipynb"

# ── Open notebooks in Colab ──────────────────────────────────────────────────

open-romsfun: ## Open romsfun PSP ROM downloader in Colab
	@open "$(COLAB_BASE)/downloads/romsfun.ipynb" 2>/dev/null \
	  || xdg-open "$(COLAB_BASE)/downloads/romsfun.ipynb"

open-hls: ## Open HLS/obfuscated stream downloader in Colab
	@open "$(COLAB_BASE)/downloads/hls-colab.ipynb" 2>/dev/null \
	  || xdg-open "$(COLAB_BASE)/downloads/hls-colab.ipynb"

open-ytdlp: ## Open yt-dlp video downloader in Colab
	@open "$(COLAB_BASE)/downloads/ytdlp-2drive.ipynb" 2>/dev/null \
	  || xdg-open "$(COLAB_BASE)/downloads/ytdlp-2drive.ipynb"

open-colab-connect: ## Open Colab SSH bridge notebook in Colab
	@open "$(COLAB_BASE)/utils/colab-connect.ipynb" 2>/dev/null \
	  || xdg-open "$(COLAB_BASE)/utils/colab-connect.ipynb"
