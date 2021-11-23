require "option_parser"

class Args
  property cmd = "", pos_args = [] of String, url = "", cluster_name = ""
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
