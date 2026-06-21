.PHONY: test test-file clean

NVIM ?= nvim
PLENARY ?= $(HOME)/.local/share/nvim/site/pack/core/opt/plenary.nvim

test:
	@$(NVIM) --headless --noplugin \
		--cmd "set rtp+=. | set rtp+=$(PLENARY)" \
		-c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}" 2>&1 \
		| grep -vE "^$$"

test-file:
	@$(NVIM) --headless --noplugin \
		--cmd "set rtp+=. | set rtp+=$(PLENARY)" \
		-c "PlenaryBustedFile $(FILE)" 2>&1 \
		| grep -vE "^$$"

clean:
	rm -rf /tmp/jdtls-nvim-test-*
