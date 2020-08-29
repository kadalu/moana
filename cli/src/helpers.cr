require "path"
require "file"
require "dir"
require "http/client"


def save_and_get_clusters_list(base_url)
  filename = Path.home.join(".moana", "clusters.json")
  url = "#{base_url}/api/clusters"
  response = HTTP::Client.get url
  content = ""
  if response.status_code == 200
    content = response.body
    Dir.mkdir_p(Path[filename].parent)
    File.write(filename, content)
  end

  content
end
