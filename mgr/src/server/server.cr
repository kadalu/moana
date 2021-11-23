require "yaml"
require "log"
require "uuid"

require "kemal"

require "./conf"
require "./plugins/*"
require "./services/*"

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
  def self.nodeid_file
    "#{GlobalConfig.workdir}/nodeid"
  end

  def self.hostname_file
    "#{GlobalConfig.workdir}/hostname"
  end

  def self.start(args)
    GlobalConfig.workdir = args.mgr_args.workdir
    GlobalConfig.logdir = args.mgr_args.logdir
    GlobalConfig.agent = args.mgr_args.agent

    if GlobalConfig.logdir == ""
      Log.setup(:info)
    else
      logfile = Path[GlobalConfig.logdir].join("mgr.log")
      Log.setup(:info, Log::IOBackend.new(File.new(logfile, "a+")))
    end

    # Generate a node ID if not exists
    if File.exists?(nodeid_file)
      GlobalConfig.local_nodeid = File.read(nodeid_file).strip
    else
      GlobalConfig.local_nodeid = UUID.random.to_s
      File.write(nodeid_file, GlobalConfig.local_nodeid)
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

    # TODO: Enable access logging if configured
    Kemal.config.logging = false

    Log.info &.emit("Starting the Storage manager ReST API server", port: "#{Kemal.config.port}")
    # Start the API server
    Kemal.run
  end
end
