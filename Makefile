.PHONY: fmt-check lint fmt

fmt-check:
	crystal tool format --check mgr/src types/src volgen/src volgen/spec clients/crystal/src

lint:
	cd lint && shards install
	./lint/bin/ameba mgr/src types/src volgen/src volgen/spec clients/crystal/src

fmt:
	crystal tool format mgr/src types/src volgen/src volgen/spec clients/crystal/src
