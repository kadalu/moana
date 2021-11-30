require "option_parser"

FUSE_MOUNT_OPTIONS            = %w[atime noatime diratime nodiratime relatime norelatime strictatime nostrictatime lazyatime nolazyatime dev nodev exec noexec suid nosuid auto_unmount]
FUSE_MOUNT_OPTIONS_WITH_VALUE = %w[context fscontext defcontext rootcontext]
OPTIONS_NOT_HANDLED           = %w[async sync dirsync mand nomand silent loud iversion noiversion nofail]

# these ones(auto,noauto,_netdev) are interpreted during system initialization
IGNORE_OPTIONS     = %w[rw auto noauto _netdev]
OPTIONS_WITH_VALUE = %w[log-level log-file transport direct-io-mode volume-name volume-id subdir-mount volfile-check server-port attribute-timeout entry-timeout negative-timeout gid-timeout lru-limit invalidate-limit fetch-attempts background-qlen congestion-threshold oom-score-adj xlator-option fuse-mountopts use-readdirp fopen-keep-cache event-history reader-thread-count auto-invalidation no-root-squash root-squash kernel-writeback-cache attr-times-granularity dump-fuse fuse-flush-handle-interrupt fuse-dev-eperm-ratelimit-ns halo-max-latency halo-max-replicas halo-min-replicas process-name fopen-keep-cache io-engine backup-volfile-servers backupvolfile-server] + FUSE_MOUNT_OPTIONS_WITH_VALUE

OPTIONS_WITHOUT_VALUE = %w[ro acl selinux worm enable-ino32 mem-accounting aux-gfid-mount thin-client resolve-gids localtime-logging global-threading fopen-keep-cache] + FUSE_MOUNT_OPTIONS + OPTIONS_NOT_HANDLED + IGNORE_OPTIONS

LOG_LEVELS   = %w[CRITICAL ERROR WARNING INFO DEBUG TRACE NONE]
OPTION_ALIAS = {
  "ro"             => "read-only",
  "transport"      => "volfile-server-transport",
  "volume-id"      => "volfile-id",
  "server-port"    => "volfile-server-port",
  "fetch-attempts" => "volfile-max-fetch-attempts",
}

# TODO: Handle below option
#  x-*)
# # comments or userspace application-specific options, drop them

module MountKadalu
  @@glusterfs_cmd = Process.find_executable("glusterfs")
  @@options = Hash(String, String).new

  def self.error(message)
    STDERR.puts message
    exit 1
  end

  # TODO: Improve this Function and remove below line
  # ameba:disable Metrics/CyclomaticComplexity
  def self.validate_and_add_option(opt_name, opt_value)
    new_name = opt_name
    if OPTION_ALIAS[opt_name]?
      new_name = OPTION_ALIAS[opt_name]
    end

    new_name = "" if IGNORE_OPTIONS.includes?(new_name)

    case new_name
    when "log-level"
      error "Invalid Log level(#{opt_name}=#{opt_value}" if LOG_LEVELS.includes?(opt_value.upcase)
      add_option("--#{new_name}", opt_value.upcase)
    when "subdir-mount"
      add_option("--#{new_name}", "/#{opt_value.lstrip("/")}")
    when "root-squash"
      if ["no", "off", "disable", "false"].includes?(opt_value.downcase)
        add_option("--no-root-squash")
      end
    when "no-root-squash"
      if ["yes", "on", "enable", "true"].includes?(opt_value.downcase)
        add_option("--no-root-squash")
      end
    when "halo-max-latency", "halo-max-replicas", "halo-min-replicas"
      add_option("--xlator-option", "*replicate*.#{new_name}=#{opt_value}")
    when "volfile-check"
      add_option("--volfile-check")
    when "volfile-server-transport"
      add_option("--volfile-id", "#{@@options["--volfile-id"]}.#{opt_value}") if @@options["--volfile-id"]?
      add_option("--#{new_name}", opt_value)
    when "volfile-id"
      add_option("--volfile-id", "#{opt_value}.#{@@options["--volfile-server-transport"]}") if @@options["--volfile-server-transport"]?
    when "fopen-keep-cache"
      add_option("--fopen-keep-cache", opt_value == "" ? "true" : opt_value)
    when "fuse-mountopts"
      if @@options["--fuse-mountopts"]?.nil?
        add_option("--fuse-mountopts", opt_value)
      else
        add_option("--fuse-mountopts", "#{@@options["--fuse-mountopts"]},#{opt_value}")
      end
    else
      add_option("--#{new_name}", opt_value)
    end
  end

  def self.parse_options(raw_options)
    raw_options.split(",").each do |opt|
      opt = opt.strip
      parts = opt.split("=")
      opt_name = parts[0].strip
      opt_value = parts.size > 1 ? parts[1].strip : ""

      if opt_value != ""
        error "Invalid Option: #{opt}" unless OPTIONS_WITH_VALUE.includes?(opt_name)
        error "Option doesn't take values: #{opt}" if OPTIONS_WITHOUT_VALUE.includes?(opt_name)
      else
        error "Invalid Option: #{opt}" unless OPTIONS_WITHOUT_VALUE.includes?(opt_name)
      end

      STDERR.puts "mount option '#{opt_name}' is not handled (yet?)" if OPTIONS_NOT_HANDLED.includes?(opt_name)

      # standard mount options to pass to the kernel
      if FUSE_MOUNT_OPTIONS.includes?(opt_name)
        if @@options["--fuse-mountopts"]?.nil?
          add_option("--fuse-mountopts", opt_name)
        else
          add_option("--fuse-mountopts", "#{@@options["--fuse-mountopts"]},#{opt_name}")
        end
      elsif FUSE_MOUNT_OPTIONS_WITH_VALUE.includes?(opt_name)
        if @@options["--fuse-mountopts"]?.nil?
          add_option("--fuse-mountopts", "#{opt_name}=\"#{opt_value}\"")
        else
          add_option("--fuse-mountopts", "#{@@options["--fuse-mountopts"]},#{opt_name}=\"#{opt_value}\"")
        end
      else
        validate_and_add_option(opt_name, opt_value)
      end
    end
  end

  def self.validate_mount_path(mount_path)
    error "ERROR: Cannot mount over root" if mount_path == ""
    error "ERROR: Cannot mount over /tmp" if mount_path == "/tmp"
    error "ERROR: Mount point does not exist" unless File.exists?(mount_path)
    error "ERROR: Mount path is not empty" unless Dir.children(mount_path).size == 0

    # TODO: Validate if already mounted
    # TODO: Validate if the mount path is another mount
    # TODO: Check recursive mount
  end

  def self.add_option(opt_name, opt_value = "")
    @@options[opt_name] = opt_value
  end

  def self.execute(cmd, args)
    stdout = IO::Memory.new
    stderr = IO::Memory.new
    status = Process.run(cmd, args: args, output: stdout, error: stderr)
    if status.success?
      {status.exit_code, stdout.to_s, ""}
    else
      {status.exit_code, "", stderr.to_s}
    end
  end

  # TODO: Improve this Function and remove below line
  # ameba:disable Metrics/CyclomaticComplexity
  def self.run(volume, mount_path, raw_options)
    if @@glusterfs_cmd.nil?
      STDERR.puts "glusterfs client is not installed"
      exit 1
    end

    unless Process.find_executable("getfattr")
      STDERR.puts "WARNING: getfattr not found, certain checks will be skipped.."
    end

    hostname = ""
    cluster_name = ""
    volume_name = ""
    volfile_path = ""

    if File.exists?(volume)
      volfile_path = volume
    else
      # Example: server1.example.com:mycluster
      hostname, _, cluster_volume_name = volume.rpartition(":")

      error "Hostname not provided" if hostname == ""
      cluster_name, _, volume_name = cluster_volume_name.rpartition("/")
      cluster_name = cluster_name.strip("/")

      error "Cluster name is not provided" if cluster_name == ""
      error "Volume name is not provided" if volume_name == ""
    end

    validate_mount_path(mount_path)

    # Snapshot Volume mount is read only
    # Also change the Volume name as understood by glusterfs
    if volume_name.includes?('@')
      add_option("--read-only")
      parts = volume_name.split("@")
      # /snaps/<snapname>/<volname> format
      volume_name = "/snaps/#{parts[1]}/#{parts[0]}"
    end

    # If Subdirectory is specified
    volume_name, _, subdir = volume_name.partition("/")
    add_option("--subdir-mount", "/#{subdir}") if subdir != ""

    # TODO: Validate Hostname
    # TODO: Handle Backup Volfile servers
    if volfile_path == ""
      add_option("--volfile-server", hostname)
      add_option("--volume-id", "/#{volume_name}")
    else
      add_option("--volfile", volfile_path)
    end

    parse_options(raw_options) unless raw_options.strip == ""

    # Set Process name
    if @@options["--process-name"]?
      add_option("--process-name", "fuse.kadalu.#{@@options["--process-name"]}")
    else
      add_option("--process-name", "fuse.kadalu")
    end

    add_option(mount_path)

    # TODO: Handle Updatedb settings

    args = [] of String
    @@options.each do |name, value|
      if value == ""
        args << name
      else
        args << "#{name}=#{value}"
      end
    end

    rc, _, err = execute(@@glusterfs_cmd.not_nil!, args)

    # If this is true, then glusterfs process returned error without
    # getting daemonized. We have made sure the logs are posted to
    # 'stderr', so no need to point them to logfile.
    unless rc == 0
      STDERR.puts err.strip
      error "Mounting glusterfs on $mount_point failed."
    end

    # TODO: Mount path inode check
  end
end
