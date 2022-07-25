require "./helpers"

command "info", "Kadalu Storage info" do |parser, _|
  parser.banner = "Usage: kadalu info [arguments]"
end

handler "info" do |args|
  api_call(args, "Failed to fetch Kadalu Storage info") do |client|
    info = client.info

    handle_json_output(info, args)

    puts "Manager URL    : #{info.manager_url}"
    puts "Server Version : #{info.version}"
    puts "CLI Version    : #{VERSION}"
    puts
  end
end
