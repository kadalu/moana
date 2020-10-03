require "json"

struct NodeConfigData
  include JSON::Serializable

  property node_id, hostname, endpoint, moana_url, cluster_id

  def initialize(@moana_url : String, @cluster_id : String, @node_id : String, @hostname : String, @endpoint : String)
  end
end

class NodeConfig
  def initialize(@moana_url : String, @workdir : String, @cluster_id : String, @node_name : String)
    @filename = "#{@workdir}/#{node_name}.json"
  end

  def initialize(@workdir : String, @node_name : String)
    @moana_url = ""
    @cluster_id = ""
    @filename = "#{@workdir}/#{node_name}.json"
  end

  def exists?
    File.exists?(@filename)
  end

  def save(node : MoanaTypes::NodeResponse)
    data = NodeConfigData.new(
      @moana_url,
      @cluster_id,
      node.id,
      node.hostname,
      node.endpoint
    )

    File.write(@filename, data.to_json)
  end

  def get
    NodeConfigData.from_json(File.read(@filename))
  end

  def self.from_conf
    workdir = ENV.fetch("WORKDIR", "")
    filename = "#{workdir}/#{ENV["NODENAME"]}.json"
    if File.exists?(filename)
      NodeConfigData.from_json(File.read(filename))
    else
      nil
    end
  end
end
