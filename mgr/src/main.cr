require "option_parser"

require "./cmds/*"

# Set VERSION during build time
VERSION = {{ env("VERSION") && env("VERSION") != "" ? env("VERSION") : `git describe --always --tags --match "[0-9]*" --dirty`.chomp.stringify }}

module CLI
  def self.run(args)
    parsed = Args.new
    parsed.url = ENV.fetch("KADALU_URL", "http://localhost:3000")

    parser = OptionParser.new do |parser_1|
      parser_1.banner = "Usage: kadalu [subcommand] [arguments]\n\nSubcommands:"

      parser_1.on("-h", "--help", "Show this help") do
        puts parser_1
        exit
      end

      parser_1.on("--mode=MODE", "Script mode") do |mode|
        parsed.script_mode = true if mode.strip.downcase == "script"
      end

      parser_1.on("--json", "Pretty print in JSON") do
        parsed.json = true
      end

      parser_1.on("--version", "Show version information") do
        puts "Kadalu Storage #{VERSION}"
        exit
      end

      parser_1.on("version", "Show version information") do
        puts "Kadalu Storage #{VERSION}"
        exit
      end

      Commands.commands.each do |name, cmd|
        parser_1.on(name, cmd.help) do
          subcmds = Commands.sub_commands(name)
          if subcmds
            subcmds.each do |s_name, s_cmd|
              parser_1.on(s_name, s_cmd.help) do
                parsed.cmd = "#{name}.#{s_name}"
                s_proc = s_cmd.proc
                s_proc.call(parser_1, parsed) if s_proc
              end
            end
          else
            parsed.cmd = name
            proc = cmd.proc
            proc.call(parser_1, parsed) if proc
          end
        end
      end
    end

    parser.unknown_args do |pargs|
      parsed.pos_args = pargs
    end

    parser.invalid_option do |flag|
      STDERR.puts "Invalid option: #{flag}"
      exit 1
    end

    parser.missing_option do |flag|
      STDERR.puts "Missing option value: #{flag}=VALUE"
      exit 1
    end

    parser.parse(args)

    # Try execute only if handler is defined
    if Commands.handlers[parsed.cmd]?
      Commands.handlers[parsed.cmd].call(parsed)
    elsif parsed.cmd == ""
      puts parser
      exit 0
    else
      STDERR.puts "Unknown command \"#{args.join(" ")}\""
      exit 1
    end
  end
end

CLI.run(ARGV)
