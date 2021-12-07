require "./services"

class StorageUnitService < Service
  getter path : String,
    args : Array(String),
    pid_file : String,
    id : String

  def escaped_path(path)
    path.strip("/").gsub("/", "-")
  end

  def initialize(volume_name, storage_unit)
    @wait = true
    @create_pid_file = false

    @path = "glusterfsd"
    @id = "#{volume_name}.#{storage_unit.node_name}.#{escaped_path(storage_unit.path)}"
    @pid_file = "/var/run/kadalu/#{@id}.pid"
    @args = [
      "--volfile-id", @id,
      "-S", "/var/run/kadalu/#{@id}.socket",
      "-p", @pid_file,
      "--brick-name", storage_unit.path,
      "-l", "/var/log/kadalu/storage_units/#{@id}.log",
      "--xlator-option",
      "*-posix.glusterd-uuid=#{GlobalConfig.local_node.id}",
      "--process-name", "storage-unit",
      "--brick-port", "#{storage_unit.port}",
      "--xlator-option",
      "%s-server.listen-port=24007" % volume_name,
      "-f", Path.new(GlobalConfig.workdir, "volfiles", "#{@id}.vol").to_s,
    ]
  end
end
