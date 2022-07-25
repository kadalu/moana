require "./helpers"

get "/api/v1" do |_env|
  # TODO: Add extra info if available
  {
    "manager_url": URI.new(
      scheme: "http", # TODO: Take this from Kemal Config
      host: GlobalConfig.local_hostname,
      port: Kemal.config.port,
      path: ""
    ).to_s,
    "version": VERSION,
  }.to_json
end
