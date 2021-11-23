require "json"

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

abstract class Service
  include JSON::Serializable

  @[JSON::Field(ignore: true)]
  @proc : Process | Nil = nil

  macro inherited
    getter name : String = {{@type.stringify.downcase}}
  end

  abstract def path : String
  abstract def args : Array(String)
  abstract def pid_file : String
  abstract def id : String

  def pid
    if @proc.nil?
      File.read(pid_file).strip.to_i
    else
      @proc.not_nil!.pid
    end
  end

  def running?
    begin
      pid = File.read(pid_file).strip.to_i
      Process.exists?(pid)
    rescue File::NotFoundError
      false
    end
  end

  def start
    return if running?

    @proc = Process.new(path, args)
    File.write(pid_file, "#{@proc.not_nil!.pid}")
  end

  def stop(force = false)
    if @proc.nil?
      begin
        pid = File.read(pid_file).strip.to_i
        Process.signal(Signal::TERM, pid) if !force
        Process.signal(Signal::KILL, pid) if force
      rescue File::NotFoundError
      end
    else
      @proc.not_nil!.terminate
    end

    File.delete(pid_file)
  end

  def restart(force = false)
    stop(force)
    start
  end

  def signal(sig)
    Process.signal(sig, pid)
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
