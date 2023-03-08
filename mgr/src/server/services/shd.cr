require "./services"

class ShdService < Service
  getter path : String,
    args : Array(String),
    pid_file : String,
    id : String

  def escaped_path(path)
    path.strip("/").gsub("/", "-")
  end

  def initialize(pool_name, node_id)
    @wait = true
    @create_pid_file = false

    @path = "glusterfs"
    @id = "shd.#{pool_name}"
    @pid_file = "/run/kadalu/#{@id}.pid"
    @args = [
      "--volfile-id", "shd/#{pool_name}",
      "-p", @pid_file,
      "-S", "/run/kadalu/#{@id}.socket",
      "-l", "/var/log/kadalu/shd/#{@id}.log",
      "--xlator-option",
      "*replicate*.node-uuid=#{node_id}",
      "--fs-display-name", "kadalu:#{@id}",
      "-f", Path.new(GlobalConfig.workdir, "volfiles", "#{@id}.vol").to_s,
    ]
  end
end
