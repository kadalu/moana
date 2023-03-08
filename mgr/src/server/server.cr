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
  class StorageManagerAPILogHandler < Kemal::BaseLogHandler
    def initialize
      @handler = HTTP::LogHandler.new
    end

    def call(context : HTTP::Server::Context)
      @handler.next = @next
      @handler.call(context)
    end

    def write(message : String)
      Log.info { message.strip }
    end
  end

  def self.start_services
    # Fetch all the Services that belong to this node
    services = [] of MoanaTypes::ServiceUnit

    if GlobalConfig.agent
      loop do
        if GlobalConfig.local_node.mgr_hostname == ""
          break
        end

        begin
          headers = HTTP::Headers{
            "Authorization" => "Bearer #{GlobalConfig.local_node.mgr_token}",
            "X-Node-ID"     => GlobalConfig.local_node.id,
          }

          mgr_url = URI.new(
            scheme: GlobalConfig.local_node.mgr_https ? "https" : "http",
            host: GlobalConfig.local_node.mgr_hostname,
            port: GlobalConfig.local_node.mgr_port,
            path: "/api/v1/nodes/#{GlobalConfig.local_node.name}/services"
          )
          resp = HTTP::Client.get(mgr_url, headers: headers)
          if resp.status_code == 200
            services = Array(MoanaTypes::ServiceUnit).from_json(resp.body)
            break
          end

          Log.error &.emit("Failed to fetch services of this node", status_code: resp.status_code)
          exit 1
        rescue Socket::ConnectError
          sleep 5.seconds
          next
        end
      end
    else
      node = Datastore.get_node(GlobalConfig.local_node.name)
      if !node.nil?
        services = Datastore.list_services(node.name)
      end
    end

    # Start all the services that were started previously
    services.each do |service|
      svc = Service.from_json(service.to_json)
      svc.start(plugin: GlobalConfig.service_mgr)
    end
  end

  def self.info_file
    "#{GlobalConfig.workdir}/info"
  end

  def self.hostname_file
    "#{GlobalConfig.workdir}/hostname"
  end

  def self.start(args)
    GlobalConfig.workdir = args.mgr_args.workdir
    GlobalConfig.logdir = args.mgr_args.logdir
    GlobalConfig.service_mgr = args.mgr_args.service_mgr

    # Set the Datastore root directory
    Datastore.init(GlobalConfig.workdir)

    GlobalConfig.agent = Datastore.agent?

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

    if args.mgr_args.hostname != ""
      GlobalConfig.local_hostname = args.mgr_args.hostname
    elsif File.exists?(hostname_file)
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

    # TODO: Fetch all the Volfiles from the Storage Manager

    start_services

    Log.info &.emit("Starting the Storage manager ReST API server", port: "#{Kemal.config.port}")

    Kemal.config.logger = StorageManagerAPILogHandler.new
    add_handler ApiExceptionHandler.new
    add_handler MgrRequestsProxyHandler.new
    add_handler AuthHandler.new

    # Start the API server
    Kemal.run do |config|
      # TODO: Enable/Disable access logging if configured
      # Kemal.config.logging = false
      config.app_name = "Kadalu Storage"
      config.powered_by_header = false
      server = config.server.not_nil!
      server.bind_tcp "0.0.0.0", 3000, reuse_port: true
    end
  end
end
