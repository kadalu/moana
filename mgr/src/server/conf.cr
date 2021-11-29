require "json"

class GlobalConfig
  class_property workdir = "",
    logdir = "",
    cluster_id = "",
    cluster_name = "",
    local_hostname : String = `hostname`.strip,
    local_node = LocalNodeData.new,
    agent = false
end

struct LocalNodeData
  include JSON::Serializable

  property cluster_name = "", id = "", name = "", token_hash = "", mgr_url = ""

  def initialize
  end
end
