require "log"

require "../config/application"
require "./watcher"

node_name = ENV.fetch("NODENAME", "")
# Set node_name as hostname itself
node_name = `hostname`.strip if node_name == ""

pfx = "http"
endpoint_https = ENV.fetch("ENDPOINT_HTTPS", "")
if endpoint_https == "yes"
  pfx = "https"
end

node_endpoint = ENV.fetch("ENDPOINT", "")
if node_endpoint == ""
  # Set hostname:PORT as endpoint if not set
  node_endpoint = "#{pfx}://#{`hostname`.strip}:#{Amber.settings.port}"
else
  # Set Port same as specified in the ENDPOINT
  Amber.settings.port = node_endpoint.split(":")[-1].to_i
end

Log.info {"Starting moana-node [{nodename=#{node_name}}, {endpoint=#{node_endpoint}}, {port=#{Amber.settings.port}}]"}

watcher = Watcher.new
watcher.start

Amber::Support::ClientReload.new if Amber.settings.auto_reload?
Amber::Server.start
