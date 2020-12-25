require "option_parser"

require "./clusters"
require "./nodes"
require "./volumes"
require "./tasks"
require "./helpers"

class MoanaCommands
  @args : Args = NoCmdArgs.new
  @pos_args = [] of String
  @gflags = Gflags.new ENV.fetch("MOANA_URL", "")

  def parse
    parser = OptionParser.new do |parser|
      parser.banner = "Usage: moana <subcommand> [arguments]"

      cluster_commands parser
      node_commands parser
      volume_commands parser
      task_commands parser

      #parser.on("-v", "--verbose", "Enabled servose output") { verbose = true }
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit
      end

      parser.unknown_args do |args|
        @pos_args = args
      end

      parser.invalid_option do |flag|
        STDERR.puts "Invalid Option: #{flag}"
        exit 1
      end

      parser.missing_option do |flag|
        STDERR.puts "Missing Option: #{flag}"
        exit 1
      end

      parser.parse

      if @gflags.moana_url == ""
        STDERR.puts "MOANA_URL environment variable is not set"
        exit 1
      end
    end

    @args.pos_args(@pos_args)

    begin
      @args.handle(@gflags)
    rescue Socket::ConnectError
      STDERR.puts "Moana Server is not reachable. Please make sure environment variable MOANA_URL=#{@gflags.moana_url} is correct"
      exit 1
    end
  end
end

commands = MoanaCommands.new
commands.parse
