require "./services"

class MigrateDataService < Service
  getter path : String,
    args : Array(String),
    pid_file : String,
    id : String

  def initialize(pool_name, storage_unit)
    @create_pid_file = true

    @path = PROGRAM_NAME == "kadalu" ? PROGRAM_NAME : Path[PROGRAM_NAME].expand.to_s
    @id = "rebalance-migrate-data-#{storage_unit.path.gsub("/", "%2F")}"
    @pid_file = "/run/kadalu/#{@id}.pid"
    @args = [
      "_rebalance", "--migrate-data",
      "#{pool_name}",
      storage_unit.path, "--volfile-servers",
      "#{storage_unit.node.name}:#{storage_unit.port}",
    ]
  end
end
