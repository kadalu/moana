# ## Managing the Moana node configuration
# Before joining to any Cluster, just after node agent is
# started, the following Configs will be available via
# environment variables or by default configurations.
#
# * **workdir** - Working directory for managing config files
#   and temporary files. env.WORKDIR or default(`/var/lib/kadalu`)
# * **hostname** - Hostname to use in all Operations, Volfiles etc.
#   `env.HOSTNAME` or default(`hostname` command).
# * **port** - Port for Node agent. `env.PORT` or default(`5001`).
# * **endpoint_https** - If HTTPS is to be used in all internal
#   communication. `env.ENDPOINT_HTTPS` or default(`no`).
# * **endpoint** - Endpoint that other nodes within the Cluster will
#   use for internal communication. `env.ENDPOINT` or
#   default(<endpoint-prefix>://<hostname>:<port>).
#   `endpoint_prefix=endpoint_https == "yes" ? "https" : "http"`
#
# Once the Node joins to a Cluster then the following additional
# configurations will be available.
#
# * **cluster_id** - ID of the Cluster to which node is joined.
# * **node_id** - Node ID assigned by the Moana Server. Use this
#   in all future communications or while getting the Task lists.
# * **moana_url** - Moana Server URL.
# * **token** - Token provided by the Moana Server once node joined
#   to the Cluster. Use this token in all future communications with
#   Moana Server.
#
# NodeConfig provides utility functions to save/fetch node configurations.

require "json"

DEFAULT_PORT = 3001

class NodeConfException < Exception
end

class NodeConf
  include JSON::Serializable

  property hostname = "",
           endpoint_https = "no",
           port : Int32 = DEFAULT_PORT,
           endpoint = "",
           workdir = "",
           config_file = "",
           cluster_id = "",
           node_id = "",
           moana_url = "",
           token = ""

  def initialize
    # Get hostname from env variable, if not
    # available then set by running the `hostname` command
    @hostname = ENV.fetch("HOSTNAME", `hostname`.strip)

    # Get Endpoint HTTPS info from env variable.
    # Set default as http
    endpoint_https = ENV.fetch("ENDPOINT_HTTPS", "")
    @pfx = "http"
    @pfx = "https" if endpoint_https == "yes"

    # Get Port info from environment variable or assign default port
    @port = ENV.fetch("PORT", "#{DEFAULT_PORT}").to_i

    # node endpoint for internal communication between the nodes.
    node_endpoint = ENV.fetch("ENDPOINT", "")
    if node_endpoint == ""
      # Set hostname:PORT as endpoint if not set
      @endpoint = "#{@pfx}://#{@hostname}:#{@port}"
    else
      # Set Port same as specified in the ENDPOINT. Ignore
      # if anything else set as env.PORT
      @port = node_endpoint.split(":")[-1].to_i
    end

    # Working directory to look for node config file
    @workdir = ENV.fetch("WORKDIR", "/var/lib/kadalu")

    # Node Config file
    @config_file = "#{@workdir}/#{@hostname}.json"
  end

  def save(moana_url, cluster_id, node)
    @moana_url = moana_url
    @cluster_id = cluster_id
    @node_id = node.id
    # TODO: Enable Token save once available
    # @token = node.token

    if node.hostname != "" && node.hostname != @hostname
      raise NodeConfException.new("Node agent hostname(#{@hostname}) is different than joined node(#{node.hostname})")
    end

    if node.endpoint != "" && node.endpoint != @endpoint
      raise NodeConfException.new("Node agent endpoint(#{@endpoint}) is different than joined node(#{node.endpoint})")
    end

    File.write(@config_file, self.to_json)
  end

  def in_cluster?
    @cluster_id != ""
  end

  def load_from_conf
    conf_from_file = NodeConf.from_json(File.read(@config_file))
    @moana_url = conf_from_file.moana_url
    @cluster_id = conf_from_file.cluster_id
    @node_id = conf_from_file.node_id
    @token = conf_from_file.token
  end

  def self.from_conf
    conf = NodeConf.new
    if File.exists?(conf.config_file)
      conf_from_file = NodeConf.from_json(File.read(conf.config_file))
      conf.moana_url = conf_from_file.moana_url
      conf.cluster_id = conf_from_file.cluster_id
      conf.node_id = conf_from_file.node_id
      conf.token = conf_from_file.token
    end

    conf
  end

  # Wait till the node joins to a Cluster. That is detected
  # by existence of config file.
  def wait
    loop do
      if !File.exists?(@config_file)
        # Node is not yet Joined to a Cluster
        # Wait for some time
        sleep 10.seconds
        next
      end

      # Read the config file and update the struct
      load_from_conf

      break
    end
  end
end
