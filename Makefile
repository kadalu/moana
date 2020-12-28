help:
	@echo "Show this Help Message"

deps:
	cd server && shards install
	cd node && shards install
	cd cli && shards install

build:
	cd server && VERSION=${VERSION} shards build
	cd node && VERSION=${VERSION} shards build
	cd cli && VERSION=${VERSION} shards build

prod-build:
	cd server && time -v shards install --production && VERSION=${VERSION} time -v shards build --static --release --stats --time
	cd node && time -v shards install --production && VERSION=${VERSION} time -v shards build --static --release --stats --time
	cd cli && time -v shards install --production && VERSION=${VERSION} time -v shards build --static --release --stats --time

build-arm64:
	time ./build_arm64_static.sh

build-amd64:
	time ./build_amd64_static.sh
