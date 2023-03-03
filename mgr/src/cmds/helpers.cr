require "option_parser"

require "kadalu_storage_manager"

class Args
  property cmd = "", pos_args = [] of String, url = "", script_mode = false, json = false
end

struct Command
  property help = "",
    proc : (OptionParser, Args -> Nil) | Nil

  def initialize(@help, @proc)
  end
end

alias SubCmd = Hash(String, Command)

module Commands
  @@commands = Hash(String, Command).new
  @@sub_commands = Hash(String, SubCmd).new
  @@handlers = Hash(String, (Args -> Nil)).new

  def self.commands
    @@commands
  end

  def self.sub_commands(name : String)
    @@sub_commands[name]?
  end

  def self.handlers
    @@handlers
  end

  def self.add_command(name, help, &block : OptionParser, Args -> Nil)
    parts = name.split(".")
    if parts.size > 1
      # Define a empty block if parent command is not defined
      if !@@commands[parts[0]]?
        @@commands[parts[0]] = Command.new("#{parts[0].capitalize}", nil)
      end
      @@sub_commands[parts[0]] = SubCmd.new if !@@sub_commands[parts[0]]?
      @@sub_commands[parts[0]][parts[1]] = Command.new(help, block)
    else
      @@commands[name] = Command.new(help, block)
    end
  end

  def self.add_handler(name, &block : Args -> Nil)
    @@handlers[name] = block
  end
end

def command(name, help, &block : OptionParser, Args -> Nil)
  Commands.add_command(name, help, &block)
end

def handler(name, &block : Args -> Nil)
  Commands.add_handler(name, &block)
end

def api_call(args, message, &block : StorageManager::Client -> Nil)
  begin
    client = StorageManager::Client.new(args.url)
    # If Token file exists then load it to client
    if File.exists?(session_file)
      client.set_api_key(MoanaTypes::ApiKey.from_json(File.read(session_file)))
    end
    block.call(client)
  rescue ex : StorageManager::ClientException
    handle_json_error(ex.message.not_nil!, args)
    STDERR.puts message
    STDERR.puts ex.message
    ex.node_errors.each do |node_err|
      STDERR.puts "  [#{node_err.node_name}] #{node_err.error}"
    end
    exit 1
  rescue ex : Socket::ConnectError
    handle_json_error(message, args)
    STDERR.puts message
    STDERR.puts ex.message
    exit 1
  end
end

def command_error(message, exit_code = 1)
  STDERR.puts message
  exit exit_code
end

def session_file
  Path.home.join(".kadalu", "session")
rescue KeyError
  Path.new("/root/.kadalu/session")
end

def prompt(label)
  print "#{label}: "
  value = (STDIN.noecho &.gets.try &.chomp).not_nil!
  puts
  value
end

def yes(label)
  print "#{label}: "
  value = STDIN.gets(chomp: true).not_nil!
  ["yes", "y", "yy", "ok", "sure", "on"].includes?(value.strip.downcase)
end

def pool_and_volume_name(value)
  pool_name, _, volume_name = value.partition("/")
  {pool_name, volume_name}
end

def handle_json_output(data, args)
  return unless args.json

  if data.nil?
    puts "{}"
  else
    puts data.to_pretty_json
  end
  exit 0
end

def handle_json_error(message, args)
  if args.json
    puts({"error": message}.to_json)
    exit 1
  end
end

def validate_pool_options(pool_options : Array)
  if pool_options.size % 2 != 0
    STDERR.puts "Pool options pairs invalid"
    exit 1
  end

  pool_opts = Hash(String, String).new
  pool_options.each_slice(2) do |opt|
    pool_opts[opt[0]] = opt[1]
  end
  pool_opts
end
