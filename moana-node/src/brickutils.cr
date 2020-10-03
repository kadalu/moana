require "xattr"

class SystemctlException < Exception
end

class CreateBrickException < Exception
end

class StartBrickException < Exception
end

class StopBrickException < Exception
end

class MkfsException < CreateBrickException
end

class MountException < CreateBrickException
end

class UnmountException < CreateBrickException
end

class UnsupportedBrickFsException < CreateBrickException
end

class XattrSupportException < CreateBrickException
end

class BrickXattrException < CreateBrickException
end

MOUNT_CMD = "mount"
UMOUNT_CMD = "umount"
VOLUME_ID_XATTR_NAME = "trusted.glusterfs.volume-id"

def execute(cmd, args)
  stdout = IO::Memory.new
  stderr = IO::Memory.new
  status = Process.run(cmd, args: args, output: stdout, error: stderr)
  if status.success?
    {status.exit_code, stdout.to_s}
  else
    {status.exit_code, stderr.to_s}
  end
end

class Brick
  def initialize(@volume : MoanaTypes::VolumeRequest, @request : MoanaTypes::BrickRequest)
  end

  def mkfs
  end

  def mount
    Dir.mkdir @request.mount_path

    args = ["-t", @volume.brick_fs, @request.device, @request.mount_path]
    ret, resp = execute(MOUNT_CMD, args)
    if ret != 0
      raise MountException.new(resp)
    end
  end

  def unmount
    args = [@request.mount_path]
    ret, resp = execute(UMOUNT_CMD, args)
    if ret != 0
      raise UnmountException.new(resp)
    end
  end

  def wipe()
    pass
  end

  def verify_xattr_support
    test_xattr_name = "user.testattr"
    test_xattr_value = "testvalue"

    begin
      xattr = XAttr.new(@request.path)
      xattr[test_xattr_name] = test_xattr_value
      val = xattr[test_xattr_name]
      if val != test_xattr_value
        raise XattrSupportException.new("Xattr value mismatch. actual=#{val} expected=#{test_xattr_value}")
      end
    rescue ex: IO::Error
      raise XattrSupportException.new("Extended attributes are not supported(Error: #{ex.os_error})")
    end
  end

  def set_xattrs
    volume_id = UUID.new(@volume.id)
    begin
      xattr = XAttr.new(@request.path)
      # if xattr[VOLUME_ID_XATTR_NAME] != volume_id.bytes
      #   raise BrickXattrException.new("Brick is already used with another Volume")
      # end
      xattr[VOLUME_ID_XATTR_NAME] = volume_id.bytes.to_slice
    rescue ex: IO::Error
      raise BrickXattrException.new("Failed to set Volume ID Xattr(Error: #{ex.os_error})")
    end
  end

  def create_dirs
    # TODO: Handle Error
    Dir.mkdir "#{@request.path}/.glusterfs"
  end

  def remove_xattrs
  end
end

class XfsBrick < Brick
  def mkfs
    cmd = "mkfs.xfs"
    args = @volume.xfs_opts.split
    args << @request.device
    ret, resp = execute(cmd, args)
    if ret != 0
      raise MkfsException.new(resp)
    end
  end
end

class ZfsBrick < Brick
  def mkfs
    dev_name = @request.device.sub("/", "_").strip("_")
    cmd = "zpool"
    args = ["create"]
    args += @volume.zfs_opts.split
    args << dev_name
    args << @request.device
    ret, resp = execute(cmd, args)
    if ret != 0
      raise MkfsException.new(resp)
    end
  end
end

class Ext4Brick < Brick
  def mkfs
    cmd = "mkfs.ext4"
    args = @volume.xfs_opts.split
    args << @request.device
    ret, resp = execute(cmd, args)
    if ret != 0
      raise MkfsException.new(resp)
    end
  end
end

class DirBrick < Brick
  def mkfs
  end

  def mount
    Dir.mkdir @request.path
  end

  def unmount
  end

  def wipe
  end
end

def brick_object(volreq, brickreq)
  case volreq.brick_fs
  when "xfs"
    XfsBrick.new volreq, brickreq
  when "zfs"
    ZfsBrick.new volreq, brickreq
  when "ext4"
    Ext4Brick.new volreq, brickreq
  else
    DirBrick.new volreq, brickreq
  end
end

def create_brick(volreq, brickreq)
  brick = brick_object(volreq, brickreq)

  # Try Creating Filesystem if not already Created
  # Do not use Force so that existing FS will not get overwritten
  brick.mkfs

  # If the Brick FS is not dir then Try mounting the already
  # created filesystem
  brick.mount

  # Create essential directories required for GlusterFS Brick
  brick.create_dirs
  
  brick.verify_xattr_support

  # Verify that the Volume ID is same as the input Volume ID
  # If the Volume ID not exists then Create that xattr
  # This xattr is used to identify that the mount point or directory
  # is not part of any other Volume.
  brick.set_xattrs
end

# def delete(volreq, wipe=false)
#   brick = brick_object(volreq, brickreq)

#   brick.remove_xattrs
#   brick.unmount

#   if wipe
#     brick.wipe
#   end
# end

def systemctl_service(name, action)
  # Enable the Service
  ret, resp = execute(
         "systemctl", [
           action,
           name
         ])
  if ret != 0
    raise SystemctlException.new("Failed to #{action} service: #{resp}")
  end
end

def start_brick(workdir, volume, brick)
  # Create the config file
  filename = "#{workdir}/#{brick.node.hostname}:#{brick.path.gsub("/", "-")}.json"
  File.write(filename, {
               "path" => brick.path,
               "node.id" => brick.node.id,
               "node.hostname" => brick.node.hostname,
               "volume.name" => volume.name,
               "port" => brick.port,
               "device" => brick.device
             }.to_json)

  service_name = "kadalu-brick@#{brick.node.hostname}:#{brick.path.gsub("/", "-")}.service"
  systemctl_service(service_name, "enable")
  systemctl_service(service_name, "start")
end

def stop_brick(workdir, volume, brick)
  service_name = "kadalu-brick@#{brick.node.hostname}:#{brick.path.gsub("/", "-")}.service"
  systemctl_service(service_name, "stop")
  systemctl_service(service_name, "disable")
end
