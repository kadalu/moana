require "json"
require "log"

require "moana_types"

require "./plugins/*"

module JSON::Serializable
  macro auto_json_discriminator(key)
    {% if @type.subclasses.size > 0 %}
      use_json_discriminator {{ key }}, {
      {% for name in @type.subclasses %}
      {{ name.stringify.downcase.id }}: {{ name.id }},
      {% end %}
    }
    {% end %}
    end
end

SERVICE_MGR_PLUGINS = {
  "systemd" => SystemdServiceManager.new,
}

abstract class Service
  include JSON::Serializable

  @[JSON::Field(ignore: true)]
  @proc : Process | Nil = nil

  getter wait = true, create_pid_file = true

  macro inherited
    getter name : String = {{@type.stringify.downcase}}
  end

  abstract def path : String
  abstract def args : Array(String)
  abstract def pid_file : String
  abstract def id : String

  def unit
    MoanaTypes::ServiceUnit.from_json(self.to_json)
  end

  def pid
    if @proc.nil?
      File.read(pid_file).strip.to_i
    else
      @proc.not_nil!.pid
    end
  end

  def running?
    pid = File.read(pid_file).strip.to_i
    # exists? returns true even for Zombie processes. /proc/<pid>/cmdline
    # will be empty if it is zombie process.
    Process.exists?(pid) && File.read("/proc/#{pid}/cmdline") != ""
  rescue File::NotFoundError
    false
  end

  def start(plugin = "")
    Log.debug &.emit("Starting the service", plugin: plugin, cmd: "#{path} #{args.join(" ")}")
    return if running?

    # Create PID file directory if not exists
    Dir.mkdir_p(Path[pid_file].parent)

    mgr = SERVICE_MGR_PLUGINS[plugin]?
    if mgr
      mgr.start(id, [path] + args)
      return
    end

    @proc = Process.new(path, args)
    File.write(pid_file, "#{@proc.not_nil!.pid}") if @create_pid_file
    if @wait
      @proc.not_nil!.wait
    else
      spawn do
        @proc.not_nil!.wait
      end
    end
  end

  def stop(plugin = "", force = false)
    Log.debug &.emit("Stopping the service", plugin: plugin, cmd: "#{path} #{args.join(" ")}")
    mgr = SERVICE_MGR_PLUGINS[plugin]?
    if mgr
      mgr.stop(id)
      return
    end

    if @proc.nil?
      begin
        pid = File.read(pid_file).strip.to_i
        Process.signal(Signal::TERM, pid) if !force
        Process.signal(Signal::KILL, pid) if force
      rescue File::NotFoundError
      rescue RuntimeError
        # TODO: Handle specific error "No such process"
      end
    else
      @proc.not_nil!.terminate
    end

    File.delete(pid_file) if File.exists?(pid_file)
  end

  def restart(plugin = "", force = false)
    stop(plugin: plugin, force: force)
    start(plugin)
  end

  def signal(sig)
    Process.signal(sig, pid)
  rescue RuntimeError
    # TODO: Handle specific error "No such process"
  end

  def save(node)
    Dir.mkdir_p("#{node}")
    File.write("#{node}/#{id}.json", {
      "name":     name,
      "path":     path,
      "args":     args,
      "pid_file": pid_file,
      "id":       id,
    }.to_json)
  end

  def delete(node)
    File.delete("#{node}/#{id}.json")
  end

  def self.load(node, id)
    data = File.read("#{node}/#{id}.json")
    Service.from_json(data)
  end

  def self.list(node)
    services = [] of Service
    return services if !File.exists?(node)

    Dir.entries(node).each do |item|
      next if item == "." || item == ".."

      services << Service.from_json(File.read("#{node}/#{item}"))
    end

    services
  end
end
