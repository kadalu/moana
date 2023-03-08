require "./services"

class StorageUnitService < Service
  getter path : String,
    args : Array(String),
    pid_file : String,
    id : String

  def escaped_path(path)
    path.strip("/").gsub("/", "-")
  end

  def initialize(pool_name, storage_unit)
    @wait = true
    @create_pid_file = false

    @path = "glusterfsd"
    @id = "#{pool_name}.#{storage_unit.node.name}.#{escaped_path(storage_unit.path)}"
    @pid_file = "/run/kadalu/#{@id}.pid"
    @args = [
      "--volfile-id", @id,
      "-S", "/run/kadalu/#{storage_unit.node.id}.#{escaped_path(storage_unit.path)}.socket",
      "-p", @pid_file,
      "--brick-name", storage_unit.path,
      "-l", "/var/log/kadalu/storage_units/#{@id}.log",
      "--xlator-option",
      "*-posix.glusterd-uuid=#{storage_unit.node.id}",
      "--process-name", "storage-unit",
      "--brick-port", "#{storage_unit.port}",
      "--xlator-option",
      "#{pool_name}-server.listen-port=#{storage_unit.port}",
      "-f", Path.new(GlobalConfig.workdir, "volfiles", "#{@id}.vol").to_s,
    ]
  end
end
