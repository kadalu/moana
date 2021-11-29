require "yaml"
require "log"
require "uuid"

require "kemal"

require "./conf"
require "./datastore/*"
require "./plugins/*"
require "./services/*"
require "./routes"

# Once all the Service definitions are added
# to services directory then below code block adds
# JSON discriminator to the main class. With the
# below code, respective instance will be created
# based on the field name "name". For example
# Service.from_json({"name": "storage_unit", ...}) will
# be loaded as StorageUnit class
abstract class Service
  auto_json_discriminator "name"
end

module StorageMgr
  def self.info_file
    "#{GlobalConfig.workdir}/info"
  end

  def self.hostname_file
    "#{GlobalConfig.workdir}/hostname"
  end

  def self.start(args)
    GlobalConfig.workdir = args.mgr_args.workdir
    GlobalConfig.logdir = args.mgr_args.logdir
    GlobalConfig.agent = args.mgr_args.agent

    # Create workdir if not exists
    Dir.mkdir_p("#{GlobalConfig.workdir}")

    if GlobalConfig.logdir == ""
      Log.setup(:info)
    else
      # Create logdir if not exists
      Dir.mkdir_p("#{GlobalConfig.logdir}")
      logfile = Path[GlobalConfig.logdir].join("mgr.log")
      Log.setup(:info, Log::IOBackend.new(File.new(logfile, "a+")))
    end

    # Generate a node ID if not exists
    if File.exists?(info_file)
      GlobalConfig.local_node = LocalNodeData.from_json(File.read(info_file).strip)
    else
      data = LocalNodeData.new
      data.id = UUID.random.to_s
      GlobalConfig.local_node = data
      File.write(info_file, data.to_json)
    end

    if File.exists?(hostname_file)
      GlobalConfig.local_hostname = File.read(hostname_file).strip
    end

    # Create Config Store directory if not exists
    loop do
      begin
        Dir.mkdir_p("#{GlobalConfig.workdir}/meta")
        break
      rescue ex : File::Error
        # Only if Kadalu Lite Meta Volume is used, the mount dir raises
        # EPERM for any write because of the mount dir is immutable
        # without the mount. Once the mount is successful the EPERM
        # error goes away. If no Volume server processes are ready then
        # the client raises ENOTCONN. Client reconnects
        # once the Volume server processes are available.
        # TODO: Somehow distingush EPERM error due to non-root user vs immutable
        if ex.os_error != Errno::EPERM && ex.os_error != Errno::ENOTCONN
          Log.error &.emit("Error creating store directory", error: "#{ex.os_error}")
          break
        end
        sleep 5.seconds
      end
    end

    # Set the Datastore root directory
    Datastore.rootdir = "#{GlobalConfig.workdir}/meta"

    # TODO: Enable/Disable access logging if configured
    # Kemal.config.logging = false

    Log.info &.emit("Starting the Storage manager ReST API server", port: "#{Kemal.config.port}")
    # Start the API server
    Kemal.run
  end
end
