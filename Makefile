.PHONY: fmt lint

fmt:
	crystal tool format --check mgr/src types/src volgen/src volgen/spec client/src

lint:
	cd lint && shards install
	./lint/bin/ameba mgr/src types/src volgen/src volgen/spec client/src

