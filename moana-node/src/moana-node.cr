require "log"

require "../config/application"
require "./watcher"

node_name = ENV.fetch("NODENAME", "")
# Set node_name as hostname itself
ENV["NODENAME"] = `hostname`.strip if node_name == ""

pfx = "http"
endpoint_https = ENV.fetch("ENDPOINT_HTTPS", "")
if endpoint_https == "yes"
  pfx = "https"
end

node_endpoint = ENV.fetch("ENDPOINT", "")
if node_endpoint == ""
  # Set hostname:PORT as endpoint if not set
  ENV["ENDPOINT"] = "#{pfx}://#{`hostname`.strip}:#{Amber.settings.port}"
else
  # Set Port same as specified in the ENDPOINT
  Amber.settings.port = node_endpoint.split(":")[-1].to_i
end

node_workdir = ENV.fetch("WORKDIR", "")
if node_workdir == ""
  ENV["WORKDIR"] = "/var/lib/moana"
end

Log.info {"Starting moana-node [{nodename=#{ENV["NODENAME"]}}, {endpoint=#{ENV["ENDPOINT"]}}, {port=#{Amber.settings.port}}, {workdir=#{ENV["WORKDIR"]}}]"}

watcher = Watcher.new
watcher.start

Amber::Support::ClientReload.new if Amber.settings.auto_reload?
Amber::Server.start
