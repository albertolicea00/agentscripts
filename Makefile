.PHONY: pull push pull-colab push-colab setup help

COLAB_PULL  = sync/pull.ipynb
COLAB_PUSH  = sync/push.ipynb
ENV_FILE    = sync/.env

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*##"}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: ## Copy .env.example → sync/.env (first time setup)
	@if [ -f $(ENV_FILE) ]; then \
		echo "sync/.env already exists — skipping."; \
	else \
		cp sync/.env.example $(ENV_FILE); \
		echo "Created $(ENV_FILE) — fill in your values before running pull/push."; \
	fi

pull: ## Pull notebooks from Drive using shell script (requires sync/.env + service account)
	@bash sync/pull.sh

push: ## Push src/ notebooks to Drive using shell script (requires sync/.env + service account)
	@bash sync/push.sh

pull-colab: ## Open pull Colab notebook in browser
	@open "https://colab.research.google.com/github/albertolicea00/collab-notbooks/blob/main/$(COLAB_PULL)" \
	  2>/dev/null || xdg-open "https://colab.research.google.com/github/albertolicea00/collab-notbooks/blob/main/$(COLAB_PULL)"

push-colab: ## Open push Colab notebook in browser
	@open "https://colab.research.google.com/github/albertolicea00/collab-notbooks/blob/main/$(COLAB_PUSH)" \
	  2>/dev/null || xdg-open "https://colab.research.google.com/github/albertolicea00/collab-notbooks/blob/main/$(COLAB_PUSH)"
