require "kemal"

before_all do |env|
  env.response.content_type = "application/json"
end

error 404 do |env|
  env.response.content_type = "application/json"
  {"error": "Invalid URL"}.to_json
end

error 500 do |env, exc|
  env.response.content_type = "application/json"
  {"error": "#{exc}"}.to_json
end

def unauthorized(env, message)
  env.response.status_code = 401
  env.response.content_type = "application/json"
  env.response.print ({"error": "Unauthorized. #{message}"}).to_json
end

class MgrRequestsProxyHandler < Kemal::Handler
  def call(env)
    # No proxy required if
    # - the current process is a Manager or
    # - it is a internal request or
    # - mgr_hostname is not set in Local node
    if GlobalConfig.local_node.mgr_hostname == "" ||
       env.request.path.starts_with?("/_api") ||
       Datastore.manager?
      return call_next(env)
    end

    mgr_url = URI.new(
      scheme: GlobalConfig.local_node.mgr_https ? "https" : "http",
      host: GlobalConfig.local_node.mgr_hostname,
      port: GlobalConfig.local_node.mgr_port,
      path: env.request.path,
      query: env.request.query_params
    )
    resp = case env.request.method
           when "GET"    then HTTP::Client.get(mgr_url, headers: env.request.headers)
           when "POST"   then HTTP::Client.post(mgr_url, headers: env.request.headers, body: env.request.body)
           when "PUT"    then HTTP::Client.put(mgr_url, headers: env.request.headers, body: env.request.body)
           when "DELETE" then HTTP::Client.delete(mgr_url, headers: env.request.headers)
           end
    if resp
      env.response.status_code = resp.status_code
      env.response.content_type = "application/json"
      env.response.print resp.body
    else
      call_next(env)
    end
  end
end

class AuthHandler < Kemal::Handler
  # Exclude user create API, Login API and Node action internal API.
  # User creation should be allowed even if unauthorized.
  # Login is always done unauthorized.
  # Node internal API handles authentication differently.
  exclude ["/api/v1/users", "/api/v1/users/:username/api-keys", "/_api/v1/:action"], "POST"

  def call(env)
    return call_next(env) if exclude_match?(env)

    user_id = env.request.headers["X-User-ID"]?
    node_id = env.request.headers["X-Node-ID"]?
    auth = env.request.headers["Authorization"]?

    return unauthorized(env, "X-User-ID/X-Node-ID is not set") if user_id.nil? && node_id.nil?
    return unauthorized(env, "Authorization is not set") if auth.nil?

    bearer, _, token = auth.partition(" ")
    if bearer.downcase != "bearer" || token == ""
      return unauthorized(env, "Invalid Authoriation header")
    end

    if !user_id.nil?
      return unauthorized(env, "Invalid credentials") unless Datastore.valid_api_key?(user_id, token)

      env.set("user_id", user_id)
    elsif !node_id.nil?
      # Request coming from the node. Always provides
      # pool_name in the URL.
      pool_name = env.params.url["pool_name"]?
      return unauthorized(env, "pool_name not provided") if pool_name.nil?

      unless Datastore.valid_node_of_a_pool?(pool_name, node_id, token)
        return unauthorized(env, "Invalid credentials")
      end

      env.set("node_id", node_id)
    end

    call_next(env)
  end
end
