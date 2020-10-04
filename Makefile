help:
	@echo "Show this Help Message"

prod-build:
	cd moana-server && shards install --production && shards build --release --static
	cd moana-node && shards install --production && shards build --release --static
	cd cli && shards install --production && shards build --release --static
