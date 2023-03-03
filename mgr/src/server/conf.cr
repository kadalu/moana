require "json"

class GlobalConfig
  class_property workdir = "",
    logdir = "",
    pool_id = "",
    pool_name = "",
    local_hostname : String = `hostname`.strip,
    local_node = LocalNodeData.new,
    agent = false,
    service_mgr = ""
end

struct LocalNodeData
  include JSON::Serializable

  property pool_name = "", id = "", name = "", token_hash = "",
    mgr_hostname = "", mgr_port = 3000, mgr_https = false, mgr_token = "", joined = false

  def initialize
  end
end
