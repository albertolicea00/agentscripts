.PHONY: help setup pull push pull-colab push-colab \
        open-romsfun open-hls open-ytdlp open-colab-connect \
        setup-colab connect-colab run-colab

help: ## Show all commands
	@echo ""
	@printf "\033[1m── Notebooks ───────────────────────────────────────\033[0m\n"
	@$(MAKE) -C notebooks help --no-print-directory
	@echo ""
	@printf "\033[1m── Scripts ─────────────────────────────────────────\033[0m\n"
	@$(MAKE) -C scripts help --no-print-directory
	@echo ""

# ── Notebook targets ──────────────────────────────────────────────────────────

setup:
	@$(MAKE) -C notebooks setup --no-print-directory

pull:
	@$(MAKE) -C notebooks pull --no-print-directory

push:
	@$(MAKE) -C notebooks push --no-print-directory

pull-colab:
	@$(MAKE) -C notebooks pull-colab --no-print-directory

push-colab:
	@$(MAKE) -C notebooks push-colab --no-print-directory

open-romsfun:
	@$(MAKE) -C notebooks open-romsfun --no-print-directory

open-hls:
	@$(MAKE) -C notebooks open-hls --no-print-directory

open-ytdlp:
	@$(MAKE) -C notebooks open-ytdlp --no-print-directory

open-colab-connect:
	@$(MAKE) -C notebooks open-colab-connect --no-print-directory

# ── Script targets ────────────────────────────────────────────────────────────

run-%:
	@$(MAKE) -C scripts run-$* --no-print-directory

setup-vps:
	@$(MAKE) -C scripts setup-vps --no-print-directory

pull-vps:
	@$(MAKE) -C scripts pull-vps --no-print-directory

push-vps:
	@$(MAKE) -C scripts push-vps --no-print-directory

setup-colab:
	@$(MAKE) -C scripts setup-colab --no-print-directory

connect-colab:
	@$(MAKE) -C scripts connect-colab --no-print-directory

run-colab:
	@$(MAKE) -C scripts run-colab --no-print-directory
