require "./helpers"

struct VolfileGetCommand < Command
  def pos_args(args : Array(String))
    if args.size < 1
      STDERR.puts "Volfile name is not specified"
      exit 1
    end

    @args.volfile.name = args[0]

    super
  end

  def handle
    if @args.volfile.filename == ""
      STDERR.puts "Output filename is not specified"
      exit 1
    end

    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = MoanaClient::Client.new(@gflags.kadalu_mgmt_server)
    volume_client = client.cluster(cluster_id).volume(@args.volume.name)

    if @args.brick.name != "" && @args.volume.name == ""
      STDERR.puts "Volume ID is required for Brick Volfile"
      exit 1
    end

    begin
      volfile = if @args.brick.name != ""
                  volume_client.brick_volfile(@args.brick.name, @args.volfile.name)
                elsif @args.volume.name != ""
                  volume_client.volfile(@args.volfile.name)
                else
                  client.cluster(cluster_id).volfile(@args.volfile.name)
                end

      # TODO: Handle file write error
      File.write(@args.volfile.filename, volfile.content)
      puts "Volfile downloaded successfully. Volfile saved to #{@args.volfile.filename}"
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts "Failed to fetch Volfile(HTTP Error: #{ex.status_code})"
      exit 1
    rescue ex : Exception
      STDERR.puts ex.message
      exit 1
    end
  end
end

class MoanaCommands
  def volfile_commands(parser)
    parser.on("volfile", "Manage #{PRODUCT} Volfiles") do
      @command_type = CommandType::VolfileGet
      parser.banner = "Usage: #{COMMAND} volfile <subcommand> [arguments]"
      parser.on("get", "Get Volfile") do
        parser.banner = "Usage: #{COMMAND} volfile get <name> [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @args.cluster.name = name }
        parser.on("-v ID", "--volume=ID", "Volume ID") { |volume_id| @args.volume.name = volume_id }
        parser.on("-b ID", "--brick=ID", "Brick Id") { |brick_id| @args.brick.name = brick_id }
        parser.on("-o OUTFILE", "--output=OUTFILE", "Output file Path") { |outfile| @args.volfile.filename = outfile }
      end
    end
  end
end

