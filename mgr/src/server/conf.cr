class GlobalConfig
  class_property workdir = "",
    logdir = "",
    cluster_id = "",
    cluster_name = "",
    local_hostname : String = `hostname`.strip,
    local_nodeid = "",
    agent = false
end
