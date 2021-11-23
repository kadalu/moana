require "kemal"

require "./db/*"

def forbidden_response
  {"error": "Forbidden"}.to_json
end

def cluster_admin?(env)
  MoanaDB.role_cluster_admin?(env.get("user_id").as(String), env.params.url["cluster_id"])
end

def cluster_maintainer?(env)
  MoanaDB.role_cluster_maintainer?(env.get("user_id").as(String), env.params.url["cluster_id"])
end

def cluster_viewer?(env)
  MoanaDB.role_cluster_viewer?(env.get("user_id").as(String), env.params.url["cluster_id"])
end

def cluster_client?(env)
  MoanaDB.role_cluster_client?(env.get("user_id").as(String), env.params.url["cluster_id"])
end

def volume_admin?(env)
  MoanaDB.role_volume_admin?(env.get("user_id").as(String), env.params.url["cluster_id"], env.params.url["volume_id"])
end

def volume_maintainer?(env)
  MoanaDB.role_volume_maintainer?(env.get("user_id").as(String), env.params.url["cluster_id"], env.params.url["volume_id"])
end

def volume_viewer?(env)
  MoanaDB.role_volume_viewer?(env.get("user_id").as(String), env.params.url["cluster_id"], env.params.url["volume_id"])
end

def volume_client?(env)
  MoanaDB.role_volume_client?(env.get("user_id").as(String), env.params.url["cluster_id"], env.params.url["volume_id"])
end
