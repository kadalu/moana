require "http/client"
require "json"
require "path"
require "file"

require "./helpers"

class Cluster
  JSON.mapping(
    id: String,
    name: String
  )
end

def cluster_id_from_name(name)
  filename = Path.home.join(".moana", "clusters.json")
  content = File.read(filename)
  cluster_data = Array(Cluster).from_json(content)
  cluster_data.each do |cluster|
    if cluster.name == name || cluster.id == name
      return cluster.id
    end
  end

  return ""
end

def show_clusters(gflags, args)
  cluster_data = Array(Cluster).from_json(save_and_get_clusters_list(gflags.moana_url))

  if cluster_data
    printf("%-36s  %-s\n", "ID", "Name")
  end
  cluster_data.each do |cluster|
    if args.name == "" || cluster.id == args.name || cluster.name == args.name
      printf("%-36s  %-s\n", cluster.id, cluster.name)
    end
  end
end

def create_cluster(gflags, args)
  url = "#{gflags.moana_url}/api/clusters"
  response = HTTP::Client.post(
    url,
    body: {name: args.name}.to_json,
    headers: HTTP::Headers{"Content-Type" => "application/json"}
  )
  if response.status_code == 201
    save_and_get_clusters_list(gflags.moana_url)
    puts "Cluster created successfully."
    puts "ID: #{Cluster.from_json(response.body).id}"
  else
    STDERR.puts response.status_code
  end
end

def update_cluster(gflags, args)
  cluster_id = cluster_id_from_name(args.name)
  url = "#{gflags.moana_url}/api/clusters/#{cluster_id}"
  response = HTTP::Client.put(
    url,
    body: {name: args.newname}.to_json,
    headers: HTTP::Headers{"Content-Type" => "application/json"}
  )

  if response.status_code == 200
    save_and_get_clusters_list(gflags.moana_url)
    puts "Cluster updated successfully"
  else
    STDERR.puts response.status_code
  end
end

def delete_cluster(gflags, args)
  cluster_id = cluster_id_from_name(args.name)
  url = "#{gflags.moana_url}/api/clusters/#{cluster_id}"
  response = HTTP::Client.delete url

  if response.status_code == 204
    save_and_get_clusters_list(gflags.moana_url)
    puts "Cluster deleted successfully"
  elsif response.status_code == 404
    STDERR.puts "Invalid Cluster name"
    exit
  else
    STDERR.puts response.status_code
  end
end
