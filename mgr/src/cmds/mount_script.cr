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
  extend self

  def system_path
    ENV.fetch("PATH", "/usr/sbin:/usr/local/sbin:/usr/bin")
  end

  @@glusterfs_cmd = Process.find_executable("glusterfs", path: system_path)
  @@getfattr_cmd = Process.find_executable("getfattr", path: system_path)
  @@options = Hash(String, String).new

  def handle_log_level_option(old_name, key, value)
    if key == "log-level"
      command_error "Invalid Log level(#{old_name}=#{value}" if LOG_LEVELS.includes?(value.upcase)
      add_option("--#{key}", value.upcase)
    end
  end

  def handle_root_squash_option(old_name, key, value)
    if key == "root-squash" && ["no", "off", "disable", "false"].includes?(value.downcase)
      add_option("--no-root-squash")
    elsif key == "no-root-squash" && ["yes", "on", "enable", "true"].includes?(value.downcase)
      add_option("--no-root-squash")
    end
  end

  def handle_halo_options(old_name, key, value)
    if ["halo-max-latency", "halo-max-replicas", "halo-min-replicas"].includes?(key)
      add_option("--xlator-option", "*replicate*.#{key}=#{value}")
    end
  end

  def add_fuse_mount_option(value)
    if @@options["--fuse-mountopts"]?.nil?
      add_option("--fuse-mountopts", value)
    else
      add_option("--fuse-mountopts", "#{@@options["--fuse-mountopts"]},#{value}")
    end
  end

  def handle_fuse_mount_options(old_name, key, value)
    # standard mount options to pass to the kernel
    if key == "fuse-mountopts"
      add_fuse_mount_option(value)
    elsif FUSE_MOUNT_OPTIONS.includes?(key)
      add_fuse_mount_option(key)
    elsif FUSE_MOUNT_OPTIONS_WITH_VALUE.includes?(key)
      add_fuse_mount_option("#{key}=\"#{value}\"")
    end
  end

  def handle_volfile_id_and_transport(old_name, key, value)
    if key == "volfile-server-transport"
      add_option("--volfile-id", "#{@@options["--volfile-id"]}.#{value}") if @@options["--volfile-id"]?
      add_option("--#{key}", value)
    elsif key == "volfile-id"
      add_option("--volfile-id", "#{value}.#{@@options["--volfile-server-transport"]}") if @@options["--volfile-server-transport"]?
    end
  end

  def validate_and_add_option(opt_name, opt_value)
    new_name = opt_name
    if OPTION_ALIAS[opt_name]?
      new_name = OPTION_ALIAS[opt_name]
    end

    new_name = "" if IGNORE_OPTIONS.includes?(new_name)

    handle_log_level_option(opt_name, new_name, opt_value)
    handle_root_squash_option(opt_name, new_name, opt_value)
    handle_halo_options(opt_name, new_name, opt_value)
    handle_fuse_mount_options(opt_name, new_name, opt_value)
    handle_volfile_id_and_transport(opt_name, new_name, opt_value)

    case new_name
    when "volfile-check"
      # Add only Key
      add_option("--volfile-check")
    when "fopen-keep-cache"
      # Set default value if value is not provided
      add_option("--fopen-keep-cache", opt_value == "" ? "true" : opt_value)
    else
      add_option("--#{new_name}", opt_value) if new_name != ""
    end
  end

  def parse_options(raw_options)
    raw_options.strip.split(",").each do |opt|
      next if opt.strip == ""

      opt_name, _, opt_value = opt.strip.partition("=")

      if opt_value != ""
        command_error "Invalid Option: #{opt}" unless OPTIONS_WITH_VALUE.includes?(opt_name)
        command_error "Option doesn't take values: #{opt}" if OPTIONS_WITHOUT_VALUE.includes?(opt_name)
      else
        command_error "Invalid Option: #{opt}" unless OPTIONS_WITHOUT_VALUE.includes?(opt_name)
      end

      STDERR.puts "mount option '#{opt_name}' is not handled (yet?)" if OPTIONS_NOT_HANDLED.includes?(opt_name)

      validate_and_add_option(opt_name, opt_value)
    end
  end

  def validate_mount_path(mount_path)
    command_error "ERROR: Cannot mount over root" if mount_path == ""
    command_error "ERROR: Cannot mount over /tmp" if mount_path == "/tmp"
    command_error "ERROR: Mount point does not exist" unless File.exists?(mount_path)
    command_error "ERROR: Mount path is not empty" unless Dir.children(mount_path).size == 0

    # TODO: Validate if already mounted
    # TODO: Validate if the mount path is another mount
    # TODO: Check recursive mount
  end

  def add_option(opt_name, opt_value = "")
    @@options[opt_name] = opt_value
  end

  def execute(cmd, args)
    stdout = IO::Memory.new
    stderr = IO::Memory.new
    status = Process.run(cmd, args: args, output: stdout, error: stderr)
    if status.success?
      {status.exit_code, stdout.to_s, ""}
    else
      {status.exit_code, "", stderr.to_s}
    end
  end

  def set_process_name
    if @@options["--process-name"]?
      add_option("--process-name", "fuse.kadalu.#{@@options["--process-name"]}")
    else
      add_option("--process-name", "fuse.kadalu")
    end
  end

  def set_volfile_server_options(hostname, volume_name, volfile_path)
    # TODO: Validate Hostname
    # TODO: Handle Backup Volfile servers
    if volfile_path == ""
      add_option("--volfile-server", hostname)
      add_option("--volfile-id", "/#{volume_name}") if @@options["--volfile-id"]?.nil?
    else
      if volume_name != "" && @@options["--volfile-id"]?.nil?
        add_option("--volfile-id", "/#{volume_name}")
      end
      add_option("--volfile", volfile_path)
    end
  end

  def options_to_args
    @@options.map do |name, value|
      value == "" ? name : "#{name}=#{value}"
    end
  end

  def volume_details(volume)
    return {"", "", "", volume} if File.exists?(volume)

    # Example: server1.example.com:mypool
    hostname, _, pool_volume_name = volume.rpartition(":")

    command_error "Hostname not provided" if hostname == ""
    pool_name, _, volume_name = pool_volume_name.rpartition("/")
    pool_name = pool_name.strip("/")

    command_error "Pool name is not provided" if pool_name == ""
    command_error "Volume name is not provided" if volume_name == ""

    {hostname, pool_name, volume_name, ""}
  end

  def run(hostname, pool_name, volume_name, volfile_path, mount_path, raw_options)
    command_error "glusterfs client is not installed" if @@glusterfs_cmd.nil?
    STDERR.puts "WARNING: getfattr not found, certain checks will be skipped.." unless @@getfattr_cmd

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

    parse_options(raw_options)
    set_volfile_server_options(hostname, volume_name, volfile_path)
    set_process_name
    add_option("--fs-display-name", "#{hostname}:#{pool_name}/#{volume_name}")

    # Subdir mount: Add slash if not added
    add_option("--subdir-mount", "/#{@@options["--subdir-mount"].lstrip("/")}") if @@options["--subdir-mount"]?

    add_option(mount_path)

    # TODO: Handle Updatedb settings

    # Execute glusterfs with all Options
    rc, _, err = execute(@@glusterfs_cmd.not_nil!, options_to_args)

    # If this is true, then glusterfs process returned error without
    # getting daemonized. We have made sure the logs are posted to
    # 'stderr', so no need to point them to logfile.
    unless rc == 0
      STDERR.puts err.strip
      command_error "Mounting glusterfs on #{mount_path} failed."
    end

    # TODO: Mount path inode check
  end
end
