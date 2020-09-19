require "../config/application"
require "./watcher"

node_name = ENV.fetch("NODENAME", "")
if node_name == ""
  STDERR.puts "Environment variable NODENAME is not provided"
  exit 1
end

node_endpoint = ENV.fetch("ENDPOINT", "")
if node_endpoint == ""
  STDERR.puts "Environment variable ENDPOINT is not provided"
  exit 1
end

watcher = Watcher.new
watcher.start

Amber::Support::ClientReload.new if Amber.settings.auto_reload?
Amber::Server.start
