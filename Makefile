help:
	@echo "Show this Help Message"

deps:
	cd server && shards install --ignore-crystal-version
	cd node && shards install --ignore-crystal-version
	cd cli && shards install --ignore-crystal-version

build:
	cd server && shards build
	cd node && shards build
	cd cli && shards build

prod-build:
	cd server && shards install --ignore-crystal-version --production && shards build --release --stats --time
	cd node && shards install --ignore-crystal-version --production && shards build --release --stats --time
	cd cli && shards install --ignore-crystal-version --production && shards build --release --stats --time

prod-build-static:
	cd server && shards install --ignore-crystal-version --production && shards build --static --release --stats --time
	cd node && shards install --ignore-crystal-version --production && shards build --static --release --stats --time
	cd cli && shards install --ignore-crystal-version --production && shards build --static --release --stats --time

build-arm64:
	time ./build_arm64_static.sh

build-amd64:
	time ./build_amd64_static.sh

lint:
	cd server && shards build --ignore-crystal-version && ./bin/ameba
	cd cli && shards build --ignore-crystal-version && ./bin/ameba
	cd client && shards build --ignore-crystal-version && ./bin/ameba
	cd connection_manager && shards build --ignore-crystal-version && ./bin/ameba
	cd node && shards build --ignore-crystal-version && ./bin/ameba
	cd types && shards build --ignore-crystal-version && ./bin/ameba
	cd volgen && shards build --ignore-crystal-version && ./bin/ameba
