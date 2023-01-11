require "xattr"
require "file_utils"
require "moana_types"

require "./helpers"

STATUS_UPDATE_GAP = 5
REBALANCE_XATTR   = "trusted.distribute.migrate-data"
FIX_LAYOUT_XATTR  = "distribute.fix.layout"
BLOCK_SIZE        = 4096

# .glusterfs
# .glusterfs/changelogs/csnap
# .glusterfs/changelogs/htime
# .glusterfs/indices/dirty
# .glusterfs/indices/entry-changes
# .glusterfs/indices/xattrop
KNOWN_DIRS_IN_DOT_GLUSTERFS = 6
WORKDIR                     = "/var/lib/kadalu"

class Rebalancer
  property fix_layout_status = MoanaTypes::FixLayoutRebalanceStatus.new
  property migrate_data_status = MoanaTypes::MigrateDataRebalanceStatus.new

  def initialize(@volume_name : String, @backend_dir : String, @ignore_paths = [".glusterfs"])
    @mount_dir = "/mnt/reb-#{@backend_dir.gsub("/", "%2F")}"
    @migrate_data_status.total_bytes = 0_i64
    @migrate_data_status.scanned_bytes = BLOCK_SIZE.to_i64
    @start_time = Time.monotonic
    @last_status_updated = Time.monotonic
    update_total_bytes
  end

  def dot_glusterfs_dirs_du
    all_dirs = [Path.new(".glusterfs")]
    @migrate_data_status.scanned_bytes += KNOWN_DIRS_IN_DOT_GLUSTERFS * BLOCK_SIZE
    while dir = all_dirs.shift?
      Dir.each_child(Path.new(@backend_dir, dir)) do |entry|
        rel_path = Path.new(dir, entry)
        backend_full_path = Path.new(@backend_dir, rel_path)
        if File.directory?(backend_full_path)
          @migrate_data_status.scanned_bytes += BLOCK_SIZE

          if entry.size == 2 && dir.basename == ".glusterfs"
            all_dirs << rel_path
          end

          next
        end

        file_size = 0
        begin
          file_info = File.info(backend_full_path, follow_symlinks: false)
          file_size = file_info.size
        rescue ex : File::Error
          next
        end

        add_scanned_bytes(file_size, 2)
      end
    end
  end

  def update_total_bytes
    stdout = IO::Memory.new
    proc = Process.new("du", ["-s", "-B1", @backend_dir], output: stdout)
    status = proc.wait
    if status.success?
      # Example output
      # 41259008 dirname
      used, _ = stdout.to_s.strip.split
      @migrate_data_status.total_bytes = used.strip.to_i64
    else
      STDERR.puts "Failed to get total used bytes. Backend dir=#{@backend_dir}"
    end
  end

  def add_scanned_bytes(val, nlinks)
    rem = val.remainder(BLOCK_SIZE)
    newval = val - rem + (rem == 0 ? 0 : BLOCK_SIZE)
    # nlinks - 1 -> For Kadalu/Gluster backend
    @migrate_data_status.scanned_bytes += (newval/(nlinks - 1)).to_i64
  end

  def status_file(rebalance_type)
    # TODO: Change the path to a subdir
    Path.new(
      WORKDIR,
      "rebalance-#{rebalance_type}-#{@backend_dir.gsub("/", "%2F")}.json"
    ).to_s
  end

  def update_migrate_data_progress(final_update = false)
    # Percentage of completion: scanned_bytes/total_bytes
    percent_progress = @migrate_data_status.scanned_bytes * 100 / @migrate_data_status.total_bytes
    # Estimated Completion Time: duration*100/(Percentage of completion)
    duration = Time.monotonic - @start_time
    return if percent_progress == 0
    estimate = (duration.seconds * 100 / percent_progress) - duration.seconds
    estimate = 0 if estimate < 0

    if final_update || (Time.monotonic - @last_status_updated).seconds > STATUS_UPDATE_GAP
      @last_status_updated = Time.monotonic

      status_file = status_file("migrate-data")

      @migrate_data_status.complete = final_update ? true : false
      @migrate_data_status.progress = percent_progress.to_i
      @migrate_data_status.duration_seconds = duration.seconds
      @migrate_data_status.estimate_seconds = estimate.to_i
      File.write(status_file + ".tmp", @migrate_data_status.to_json)
      File.rename(status_file + ".tmp", status_file)
    end
  end

  def update_fix_layout_progress(final_update = false)
    duration = Time.monotonic - @start_time

    if final_update || (Time.monotonic - @last_status_updated).seconds > STATUS_UPDATE_GAP
      @last_status_updated = Time.monotonic
      status_file = status_file("fix-layout")
      @fix_layout_status.complete = final_update ? true : false
      @fix_layout_status.duration_seconds = duration.seconds
      File.write(status_file + ".tmp", @fix_layout_status.to_json)
      File.rename(status_file + ".tmp", status_file)
    end
  end

  def migrate_data
    dot_glusterfs_dirs_du

    all_dirs = [Path.new("")]
    while dir = all_dirs.shift?
      Dir.each_child(Path.new(@backend_dir, dir)) do |entry|
        rel_path = Path.new(dir, entry)

        # TODO: subdirectories and files inside ignored dirs
        # size are not added to the total bytes
        next if @ignore_paths.includes?(rel_path.to_s)

        backend_full_path = Path.new(@backend_dir, rel_path)
        # puts "backend_full_path: #{backend_full_path}"
        if File.directory?(backend_full_path)
          # TODO: Fix ENOENT issue in mount and remove list entries for,
          # Correct use of rebalance multiprocesses & improved time complexity.
          _entries = Dir.new(Path.new(@mount_dir, rel_path).to_s).entries
          @migrate_data_status.scanned_bytes += BLOCK_SIZE
          all_dirs << rel_path
          next
        end
        mnt_full_path = Path.new(@mount_dir, rel_path)
        # Stat the file from the @backend_dir to check the size
        begin
          file_info = File.info(backend_full_path, follow_symlinks: false)
          file_size = file_info.size
        rescue ex : File::Error
          next if ex.os_error == Errno::ENOENT

          STDERR.puts "Failed to get info of the file. file=#{rel_path} Error=#{ex}"
          next
        end


        # puts "@mount_dir: #{@mount_dir}"
        # puts "rel_path: #{rel_path}"
        # puts "mnt_full_path: #{mnt_full_path}"
        # puts "mnt_full_path.to_s: #{mnt_full_path.to_s}"

        # if File.exists?(mnt_full_path.to_s)
        #   puts "The File #{mnt_full_path.to_s} exists"
        # end

        # puts "going to trigger"

        # Issue Trigger rebalance xattr
        begin
          XAttr.set(mnt_full_path.to_s, REBALANCE_XATTR, "1", no_follow: true)
          # puts "setting xattr for: #{mnt_full_path.to_s}"
        # rescue ex : IO::Error
        #   # DHT raises EEXIST if rebalance is not required for a file
        #   # If file is deleted in after directory listing and before calling this setxattr
        #   if ex.os_error != Errno::EEXIST && ex.os_error != Errno::ENOENT
        #     puts "error"
        #     STDERR.puts "Failed to trigger rebalance. file=#{rel_path} Error=#{ex}"
        #   end
        rescue ex
          puts "other err: #{ex.message}"
        end

        # begin
        #   puts XAttr.get(mnt_full_path.to_s, REBALANCE_XATTR, no_follow: true)
        # rescue ex
        #   puts ex.message
        # end


        # begin
        #   XAttr.set(mnt_full_path.to_s, "name", "v")
        # rescue ex
        #   puts ex.message
        # end

        # begin
        #   puts XAttr.get(mnt_full_path.to_s, "name")
        # rescue ex
        #   puts ex.message
        # end

        # Increment if rebalance complete or rebalance not required
        # or if any other error.
        add_scanned_bytes(file_size, file_info.@stat.st_nlink)

        update_migrate_data_progress
      end
    end

    # Crawl complete, so update scanned_bytes to 100%
    @migrate_data_status.scanned_bytes = @migrate_data_status.total_bytes
    update_migrate_data_progress(true)
  end

  def fix_layout
    dot_glusterfs_dirs_du

    all_dirs = [Path.new("")]
    while dir = all_dirs.shift?
      @fix_layout_status.total_dirs += 1
      mnt_full_path = Path.new(@mount_dir, dir)

      # Issue Trigger rebalance xattr
      begin
        XAttr.set(mnt_full_path.to_s, FIX_LAYOUT_XATTR, "yes", no_follow: true)
      rescue ex : IO::Error
        # DHT raises EEXIST if rebalance is not required for a file
        # If file is deleted in after directory listing and before calling this setxattr
        if ex.os_error != Errno::EEXIST && ex.os_error != Errno::ENOENT
          STDERR.puts "Failed to trigger fix-layout rebalance. file=#{dir} Error=#{ex}"
        end
      end

      # Search subdirs
      Dir.each_child(Path.new(@backend_dir, dir)) do |entry|
        rel_path = Path.new(dir, entry)

        # TODO: subdirectories and files inside ignored dirs
        # size are not added to the total bytes
        next if @ignore_paths.includes?(rel_path.to_s)

        backend_full_path = Path.new(@backend_dir, rel_path)
        next unless File.directory?(backend_full_path)

        all_dirs << rel_path

        update_fix_layout_progress
      end
    end

    update_fix_layout_progress(true)
  end

  def mount(volfile_servers)
    Dir.mkdir_p @mount_dir

    # TODO: Handle umount errors except mount not exists
    execute("umount", [@mount_dir])

    # TODO: Handle errors
    execute("chattr", ["+i", @mount_dir])

    args = [
      "--volfile-id", @volume_name,
      "--process-name", "fuse",
      "--fs-display-name", "kadalu:rebalance-%s" % @volume_name,
      "-l", "/var/log/kadalu/rebalance-mnt-#{@backend_dir.gsub("/", "%2F")}.log",
      "--client-pid", "-3",
    ]

    volfile_servers.each do |server|
      args << "--volfile-server"
      args << server
    end

    args << @mount_dir

    # TODO: Handle Mount failure and other errors
    execute("glusterfs", args)
  end

  def umount
    # TODO: Handle umount errors except mount not exists
    execute("umount", [@mount_dir])

    # TODO: Handle errors
    execute("chattr", ["-i", @mount_dir])

    FileUtils.rmdir(@mount_dir)
  end
end

struct RebalanceArgs
  property fix_layout = false, migrate_data = false,
    volfile_servers = [] of String
end

class Args
  property rebalance_args = RebalanceArgs.new
end

command "_rebalance", "Rebalance process" do |parser, args|
  parser.banner = "Usage: kadalu _rebalance <pool-name>/<volume-name> <storage-unit-path> [arguments]"

  parser.on("--volfile-servers=SERVERS", "List of Volfile Servers") do |servers|
    args.rebalance_args.volfile_servers = servers.split(" ")
  end

  parser.on("--fix-layout", "Fix layout") do
    args.rebalance_args.fix_layout = true
  end

  parser.on("--migrate-data", "Migrate Data") do
    args.rebalance_args.migrate_data = true
  end
end

handler "_rebalance" do |args|
  command_error "Storage unit path or Mount path is not specified" if args.pos_args.size < 2

  command_error "Volfile servers not provided" if args.rebalance_args.volfile_servers.empty?

  _pool_name, volume_name = pool_and_volume_name(args.pos_args[0])
  command_error "Volume name not specified" if volume_name == ""

  reb = Rebalancer.new(volume_name, args.pos_args[1])

  if args.rebalance_args.fix_layout
    status_file = reb.status_file("fix-layout")
    do_rebalance = true
    if File.exists?(status_file)
      data = MoanaTypes::FixLayoutRebalanceStatus.from_json(File.read(status_file))
      do_rebalance = false if data.complete
    end

    if do_rebalance
      reb.mount(args.rebalance_args.volfile_servers)
      reb.fix_layout
      reb.umount
    else
      STDERR.puts "Status file of previous fix-layout exists. Please remove it to start fix-layout again"
    end
  end

  if args.rebalance_args.migrate_data
    status_file = reb.status_file("migrate-data")
    do_rebalance = true
    if File.exists?(status_file)
      data = MoanaTypes::MigrateDataRebalanceStatus.from_json(File.read(status_file))
      do_rebalance = false if data.complete
    end

    if do_rebalance
      reb.mount(args.rebalance_args.volfile_servers)
      reb.migrate_data
      reb.umount
    else
      STDERR.puts "Status file of previous migrate-data exists. Please remove it to start migrate-data again"
    end
  end
end
