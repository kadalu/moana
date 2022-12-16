require "./services"

class FixLayoutService < Service
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
    @id = "#{volume_name}"
    @pid_file = "/run/kadalu/#{@id}.pid"
    @args = [
      "--process-name", "rebalance",
      "--volfile-id", "#{@id}",
      "-p", @pid_file,
      "-S", "/run/kadalu/#{@id}.socket",
      "-l", "/var/log/kadalu/storage_units/#{@id}.log",
      "--xlator-option",
      "*distribute.use-readdirp=yes",
      "--xlator-option",
      "*distribute.lookup-unhashed=yes",
      "--xlator-option",
      "*distribute.assert-no-child-down=yes",
      "--xlator-option",
      "replicate.data-self-heal=off",
      "--xlator-option",
      "replicate.metadata-self-heal=off",
      "--xlator-option",
      "replicate.entry-self-heal=off",
      "--xlator-option",
      "*distribute.readdir-optimize=on",
      "--xlator-option",
      "*distribute.rebalance-cmd=4",
      "--xlator-option",
      "*distribute.node-uuid=#{node_id}",
      "--xlator-option",
      "*distribute.commit-hash=12345678",
      "-f", Path.new(GlobalConfig.workdir, "volfiles", "#{@id}.vol").to_s,
    ]
  end
end
