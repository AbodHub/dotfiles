SCRIPTS := bootstrap.sh install configs/theme/bin/theme $(wildcard configs/theme/tinty/hooks/*.sh) $(wildcard scripts/*.sh)

.PHONY: lint fmt fmt-check test check

lint:
	shellcheck $(SCRIPTS)

fmt:
	shfmt -w -i 4 -ci $(SCRIPTS)

fmt-check:
	shfmt -d -i 4 -ci $(SCRIPTS)

test:
	bats tests/

check: lint fmt-check test
