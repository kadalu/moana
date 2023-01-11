require "./services"

class FixLayoutService < Service
  getter path : String,
    args : Array(String),
    pid_file : String,
    id : String

  def initialize(pool_name, volume_name, storage_unit)
    @create_pid_file = true

    @path = PROGRAM_NAME == "kadalu" ? PROGRAM_NAME : Path[PROGRAM_NAME].expand.to_s
    @id = "rebalance-fix-layout-#{storage_unit.path}"
    @pid_file = "/run/kadalu/#{@id}.pid"
    @args = [
      "_rebalance", "--fix-layout",
      "#{pool_name}/#{volume_name}",
      storage_unit.path, "--volfile-servers",
      "#{storage_unit.node.name}:#{storage_unit.port}",
    ]
  end
end
