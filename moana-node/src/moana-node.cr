require "../config/application"
require "./watcher"

moana_url = ENV.fetch("MOANA_URL", "")
if moana_url == ""
  STDERR.puts "Environment variable MOANA_URL is not provided"
  exit 1
end

cluster_id = ENV.fetch("CLUSTER_ID", "")
if cluster_id == ""
  STDERR.puts "Environment variable CLUSTER_ID is not provided"
  exit 1
end

node_id = ENV.fetch("NODE_ID", "")
if node_id == ""
  STDERR.puts "Environment variable NODE_ID is not provided"
  exit 1
end

# TODO: Get this from settings
endpoint = ENV.fetch("ENDPOINT", "")
if endpoint == ""
  STDERR.puts "Environment variable ENDPOINT is not provided"
  exit 1
end

watcher = Watcher.new moana_url, cluster_id, node_id, endpoint
watcher.start

Amber::Support::ClientReload.new if Amber.settings.auto_reload?
Amber::Server.start
