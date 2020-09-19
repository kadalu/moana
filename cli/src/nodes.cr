require "http/client"
require "json"
require "path"
require "file"

require "./helpers"

def show_nodes(gflags, args)
  cluster_id = cluster_id_from_name(args.cluster_name)
  url = "#{gflags.moana_url}/api/clusters/#{cluster_id}/nodes"
  response = HTTP::Client.get url
  content = "[]"
  if response.status_code == 200
    content = response.body
  end
  node_data = Array(Node).from_json(content)

  if node_data
    printf("%-36s  %-25s  %-s\n", "ID", "Name", "Endpoint")
  end
  node_data.each do |node|
    if args.name == "" || node.id == args.name || node.hostname == args.name
      printf("%-36s  %-25s  %-s\n", node.id, node.hostname, node.endpoint)
    end
  end
end

def create_node(gflags, args)
  cluster_id = cluster_id_from_name(args.cluster_name)
  url = "#{args.endpoint}/api/join"
  response = HTTP::Client.post(
    url,
    body: {cluster_id: cluster_id, moana_url: gflags.moana_url, token: args.token}.to_json,
    headers: HTTP::Headers{"Content-Type" => "application/json"}
  )
  if response.status_code == 201
    save_and_get_clusters_list(gflags.moana_url)
    puts "Node joined successfully."
    puts "ID: #{Node.from_json(response.body).id}"
  else
    STDERR.puts response.status_code
  end
end

def update_node(gflags, args)
  cluster_id, node_id = cluster_and_node_id_from_name(args.cluster_name, args.name)
  url = "#{gflags.moana_url}/api/clusters/#{cluster_id}/nodes/#{node_id}"
  response = HTTP::Client.put(
    url,
    body: {hostname: args.newname, endpoint: args.endpoint}.to_json,
    headers: HTTP::Headers{"Content-Type" => "application/json"}
  )

  if response.status_code == 200
    save_and_get_clusters_list(gflags.moana_url)
    puts "Node updated successfully"
  else
    STDERR.puts response.status_code
  end
end

def delete_node(gflags, args)
  cluster_id, node_id = cluster_and_node_id_from_name(args.cluster_name, args.name)
  url = "#{gflags.moana_url}/api/clusters/#{cluster_id}/#{node_id}"
  response = HTTP::Client.delete url

  if response.status_code == 204
    save_and_get_clusters_list(gflags.moana_url)
    puts "Node removed from the Cluster"
  elsif response.status_code == 404
    STDERR.puts "Invalid Cluster/Node name"
    exit
  else
    STDERR.puts response.status_code
  end
end
