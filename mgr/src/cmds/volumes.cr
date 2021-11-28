require "./helpers"
require "./volume_create_parser"

command "volume.create", "Kadalu Storage Volume Create" do |parser, _|
  parser.banner = "Usage: kadalu volume create CLUSTER/VOLNAME TYPE STORAGE_UNITS [arguments]"
end

handler "volume.create" do |args|
  begin
    req = VolumeRequestParser.parse(args.pos_args)
    args.cluster_name = req.cluster_name
    api_call(args, "Failed to Create Volume") do |client|
      volume = client.cluster(args.cluster_name).create_volume(req)
      puts "Volume #{req.name} created successfully"
      puts "ID: #{volume.id}"
    end
  rescue ex : InvalidVolumeRequest
    STDERR.puts "Volume create failed"
    STDERR.puts ex
    exit 1
  end
end
