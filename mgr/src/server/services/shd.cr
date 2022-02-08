require "./services"

class ShdService < Service
  getter path : String,
    args : Array(String),
    pid_file : String,
    id : String

  def escaped_path(path)
    path.strip("/").gsub("/", "-")
  end

  def initialize(volume_name, node_id)
    @wait = true
    @create_pid_file = false

    @path = "glusterfs"
    @id = "shd.#{volume_name}"
    @pid_file = "/var/run/kadalu/#{@id}.pid"
    @args = [
      "--volfile-id", "shd/#{volume_name}",
      "-p", @pid_file,
      "-S", "/var/run/kadalu/#{@id}.socket",
      "-l", "/var/log/kadalu/shd/#{@id}.log",
      "--xlator-option",
      "*replicate*.node-uuid=#{node_id}",
      "--fs-display-name", "kadalu:#{@id}",
      "-f", Path.new(GlobalConfig.workdir, "volfiles", "#{@id}.vol").to_s,
    ]
  end
end
