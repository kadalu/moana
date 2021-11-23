require "./helpers"
require "../datastore/*"

post "/api/v1/clusters" do |env|
  name = env.params.json["name"].as(String)

  # TODO: Cluster name validations
  env.response.status_code = 201

  # If Cluster already exists then Store returns the Cluster object
  # TODO: Handle if Datastore is down or any other errors
  cluster = Datastore.create_cluster(name)
  cluster.to_json
end
