require "regex"

class BrickRequest
  include JSON::Serializable

  property node_id : String?
  property path : String
  property device : String
end

class VolumeCreateRequest
  include JSON::Serializable

  property name, replica_count, disperse_count, brick_fs, bricks

  def initialize(@name : String,
                 @replica_count : Int32 = 1,
                 @disperse_count : Int32 = 1,
                 @brick_fs : String = "dir",
                 @bricks = [] of BrickRequest
                )
  end
end

class VolumeCreateData
  @valid = true
  def initialize(@params : Amber::Validators::Params)
    @bricks = Array(BrickRequest).from_json(@params["bricks"])
  end

  def validate_volname
    return unless @valid

    match = /^[[:alpha:]][[:alnum:]]+$/ =~ @params["name"]
    if match.nil?
      @error = "Invalid Volume name"
      @valid = false
    end
  end

  def validate_replica_opts
    return unless @valid

    cnt = 1
    if @params["replica_count"]?
      cnt = @params["replica_count"].to_i
    end

    if cnt > 1 && @bricks.size % cnt != 0
      @error = "Bricks count not matching with replica count"
      @valid = false
    end
  end

  def validate_disperse_opts
    return unless @valid

    cnt = 1
    if @params["disperse_count"]?
      cnt = @params["disperse_count"].to_i
    end

    if cnt > 1 && @bricks.size % cnt != 0
      @error = "Bricks count not matching with disperse count"
      @valid = false
    end
  end

  def validate_brick_fs
    return unless @valid

    if !["zfs", "xfs", "ext4", "dir"].includes?(@params["brick_fs"])
      @error = "Unsupported Brick FS"
      @valid = false
    end
  end

  def validate_dir_path
    return unless @valid

    non_path = @bricks.find { |brick| brick.path == "" }
    if @params["brick_fs"] && !non_path.nil?
      @error = "Brick path not specified"
      @valid = false
    end
  end

  def validate_device_path
    return unless @valid

    non_dev = @bricks.find { |brick| brick.device == "" }
    if ["zfs", "xfs", "ext4"].includes?(@params["brick_fs"]) && !non_dev.nil?
      @error = "Brick device not specified"
      @valid = false
    end
  end

  def validate_bricks
    return unless @valid

    if @bricks.size == 0
      @error = "No bricks specified"
      @valid = false
    end
  end

  def validate_required(name)
    return unless @valid

    if !@params[name]?
      @error = "#{name} is required field"
      @valid = false
    end
  end

  def valid?
    @valid
  end

  def error
    @error
  end

  def data
    VolumeCreateRequest.new(
      name: @params["name"],
      replica_count: @params["replica_count"].to_i,
      disperse_count: @params["disperse_count"].to_i,
      brick_fs: @params["brick_fs"],
      bricks: @bricks
    )
  end

  def validate
    validate_required("name")
    validate_required("bricks")
    validate_bricks
    validate_volname
    validate_replica_opts
    validate_disperse_opts
    validate_brick_fs
    validate_device_path
    validate_dir_path
  end
end

