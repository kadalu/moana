class CreateBrickException < Exception
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

class BrickRequest
  
end

class Brick
  def initialize(@request : BrickRequest)
  end

  def mount
    Dir.mkdir @request.mount_path

    mount('xfs', @request.device, @request.mount_path)
    args = ['-t', @request.fstype]
    args << src
    args << mnt
    ret, out = execute(MOUNT_CMD, args)
    if ret != 0
      raise MountException(out)
    end
  end

  def umount
    args = [@request.mount_path]
    ret, out = execute(UMOUNT_CMD, args)
    if ret != 0
      raise UnmountException(out)
    end
  end

  def wipe()
    pass
  end

  def verify_xattr_support
    # """Verify Brick dir supports xattrs"""
    # test_xattr_name = "user.testattr"
    # test_xattr_value = b"testvalue"
    # try:
    #     xattr.set(self.data['path'], test_xattr_name, test_xattr_value)
    #     val = xattr.get(self.data['path'], test_xattr_name)
    #     if val != test_xattr_value:
    #         raise XattrSupportError(
    #             f"Xattr value mismatch. actual={val}  expected={test_xattr_value}"
    #         )
    # except OSError as err:
    #     raise XattrSupportError(
    #         f"Extended attributes are not supported: {err}"
    #     )
  end

  def set_xattrs
    # volume_id_bytes = uuid.UUID(self.data["volume_id"]).bytes
    # try:
    #     xattr.set(self.data["path"], VOLUME_ID_XATTR_NAME,
    #               volume_id_bytes, xattr.XATTR_CREATE)
    # except FileExistsError:
    #     pass
    # except OSError as err:
    #     raise BrickXattrError(
    #         f"Unable to set volume-id on brick root: {err}"
    #     )

    # volume_id = str(uuid.UUID(bytes=xattr.get(self.data["path"], VOLUME_ID_XATTR_NAME)))
    # if volume_id != self.data["volume_id"]:
    #     raise BrickXattrError("Brick is already used with another Volume")
  end

  def create_dirs
    # os.makedirs(os.path.join(self.data["path"], ".glusterfs"),
    #         mode=0o755,
    #         exist_ok=True)
  end

  def remove_xattrs
  end
end

class XfsBrick < Brick
  def mkfs
    cmd = ['mkfs.xfs']
    args = @request.xfs_opts.split
    args << @request.device
    ret, out = execute(cmd, args)
    if ret != 0
      raise MkfsException(out)
    end
  end
end

class ZfsBrick < Brick
  def mkfs
    dev_name = @request.device.replace('/', '_').strip('_')
    cmd = ["zpool"]
    args = ["create"]
    args += @request.zfs_opts.split
    args << dev_name
    args << @request.device
    ret, out = execute(cmd, args)
    if ret != 0
      raise MkfsException(out)
    end
  end
end

class Ext4Brick < Brick
  def mkfs
    cmd = ['mkfs.ext4']
    args = @request.xfs_opts.split
    args << @request.device
    ret, out = execute(cmd, args)
    if ret != 0
      raise MkfsException(out)
    end
  end
end

class DirBrick < Brick
  def mkfs
  end

  def mount
  end

  def unmount
  end

  def wipe
  end
end

# def create(data):
#     # Validate for supported Brick Filesystems
#     brick_fs = data.get("brick_fs", "dir")
#     BrickFsClass = globals().get(f'{brick_fs.capitalize()}Brick', None)
#     if BrickFsClass is None:
#         raise UnsupportedBrickFs(brick_fs)

#     # Load respective Fs Class instance, so that it will
#     # be available as `brick.fs`
#     brick = Brick(data, BrickFsClass)

#     # Try Creating Filesystem if not already Created
#     # Do not use Force so that existing FS will not get overwritten
#     brick.fs.mkfs()

#     # If the Brick FS is not dir then Try mounting the already
#     # created filesystem
#     brick.fs.mount()

#     # Create essential directories required for GlusterFS Brick
#     brick.create_dirs()

#     brick.verify_xattr_support()

#     # Verify that the Volume ID is same as the input Volume ID
#     # If the Volume ID not exists then Create that xattr
#     # This xattr is used to identify that the mount point or directory
#     # is not part of any other Volume.
#     brick.set_xattrs()


# def delete(data, wipe=False):
#     # Validate for supported Brick Filesystems
#     brick_fs = data.get("brick_fs", "dir")
#     BrickFsClass = globals().get(f'{brick_fs.capitalize()}Brick', None)
#     if BrickFsClass is None:
#         raise UnsupportedBrickFs(brick_fs)

#     brick = Brick(data, BrickFsClass)

#     brick.remove_xattrs()
#     brick.fs.umount()

#     if wipe:
#         brick.fs.wipe()
