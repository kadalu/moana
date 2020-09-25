require "http/client"
require "json"
require "path"
require "file"

require "./helpers"

def show_clusters(gflags, args)
  cluster_data = Array(Cluster).from_json(save_and_get_clusters_list(gflags.moana_url))
  default_cluster_id = default_cluster()
  if cluster_data
    printf(" %-36s  %-s\n", "ID", "Name")
  end
  cluster_data.each do |cluster|
    if args.name == "" || cluster.id == args.name || cluster.name == args.name
      pfx = " "
      pfx = "*" if cluster.id == default_cluster_id
      printf("%s%-36s  %-s\n", pfx, cluster.id, cluster.name)
    end
  end
end

def save_default_cluster(cluster_id)
  filename = Path.home.join(".moana", "default_cluster")
  File.write(filename, cluster_id)
end

def set_default_cluster(gflags, args)
  cluster_id = cluster_id_from_name(args.name)
  save_default_cluster(cluster_id)
  puts "Default cluster set successfully.\n"
  puts "Note: The default cluster details is stored locally in this node"
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
    default_cluster_id = default_cluster()
    puts "Cluster created successfully."
    puts "ID: #{Cluster.from_json(response.body).id}"
    if default_cluster_id == ""
      save_default_cluster(Cluster.from_json(response.body).id)
      puts "\nSaved as default Cluster"
    end
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
    default_cluster_id = default_cluster()
    save_and_get_clusters_list(gflags.moana_url)
    # If the Cluster deleted is the default Cluster then
    # reset default cluster.
    if default_cluster_id == cluster_id
      save_default_cluster("")
    end
    puts "Cluster deleted successfully"
  elsif response.status_code == 404
    STDERR.puts "Invalid Cluster name"
    exit
  else
    STDERR.puts response.status_code
  end
end
