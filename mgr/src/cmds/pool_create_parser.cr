require "moana_types"

enum TokenKind
  TypeKeyword
  Numeric
  StorageUnit
  PoolName
end

TYPE_KEYWORDS = [
  "replica",
  "mirror",
  "disperse",
  "data",
  "redundancy",
  "arbiter",
]

class InvalidPoolRequest < Exception
end

struct Token
  property kind : TokenKind, value : String

  def initialize(@kind, @value)
  end
end

module PoolRequestParser
  def self.next_token(tokens)
    token = tokens.next

    token.is_a?(Iterator::Stop) ? nil : token
  end

  def self.storage_unit_parse(value)
    # TODO: Handle Proper spliting with IPv6 IP as hostname
    parts = value.split(":")
    if parts.size == 3
      {parts[0], parts[1], parts[2]}
    elsif parts.size == 2
      {parts[0], "0", parts[1]}
    else
      {"", "0", parts[0]}
    end
  end

  def self.tokenizer(args)
    tokens = [] of Token

    args.each_with_index do |arg, idx|
      if TYPE_KEYWORDS.includes?(arg)
        tokens << Token.new(TokenKind::TypeKeyword, arg)
        next
      end

      begin
        arg.to_i
        tokens << Token.new(TokenKind::Numeric, arg)
        next
      rescue ArgumentError
      end

      if idx == 0
        tokens << Token.new(TokenKind::PoolName, arg)
        next
      end

      tokens << Token.new(TokenKind::StorageUnit, arg)
    end

    tokens
  end

  def self.disperse_and_redundancy_count(disperse, data, redundancy)
    if data > 0 && redundancy > 0
      return {data + redundancy, redundancy}
    end

    if data > 0 && disperse > 0
      return {disperse, disperse - data}
    end

    {disperse, redundancy}
  end

  def self.subvol_size(counts)
    if counts["replica"] > 0 || counts["mirror"] > 0
      counts["replica"] + counts["mirror"] + counts["arbiter"]
    elsif counts["disperse"] > 0 || counts["data"] > 0 || counts["redundancy"] > 0
      disp_count, _ = disperse_and_redundancy_count(
        counts["disperse"],
        counts["data"],
        counts["redundancy"]
      )
      disp_count
    else
      1
    end
  end

  def self.replica_keyword(replica_count, mirror_count)
    if replica_count > 0
      "replica"
    elsif mirror_count > 0
      "mirror"
    else
      ""
    end
  end

  def self.distribute_group_count_based(counts, storage_units)
    grps = [] of MoanaTypes::DistributeGroup
    subvol_size = subvol_size(counts)
    storage_units.each_slice(subvol_size) do |grp_storage_units|
      dist_group = MoanaTypes::DistributeGroup.new
      dist_group.replica_count = counts["replica"] + counts["mirror"]
      dist_group.arbiter_count = counts["arbiter"]
      dist_group.disperse_count, dist_group.redundancy_count = disperse_and_redundancy_count(
        counts["disperse"],
        counts["data"],
        counts["redundancy"]
      )
      dist_group.replica_keyword = replica_keyword(
        counts["replica"],
        counts["mirror"]
      )
      dist_group.storage_units = grp_storage_units.map do |storage_unit|
        hostname, port, path = storage_unit_parse(storage_unit)
        MoanaTypes::StorageUnit.new(hostname, port.to_i, path)
      end
      grps << dist_group
    end

    grps
  end

  def self.different_type_exists(storage_units, current_keyword)
    if ["replica", "mirror", "arbiter"].includes?(current_keyword)
      disperse_related_count = storage_units["disperse"].size + \
        storage_units["redundancy"].size + \
          storage_units["data"].size

      return true if disperse_related_count > 0
    end

    if ["disperse", "data", "redundancy"].includes?(current_keyword)
      replica_related_count = storage_units["replica"].size +
                              storage_units["mirror"].size +
                              storage_units["arbiter"].size

      return true if replica_related_count > 0
    end

    false
  end

  # When parser encounters the type keyword or at the end of the
  # parsing, find out one distribute group is already parsed or not.
  # Return None if parsing of a distribute group is not complete else
  # return the distribute group object.
  def self.distribute_group(storage_units, current_keyword)
    if !current_keyword.nil? && storage_units[current_keyword].size == 0 && !different_type_exists(storage_units, current_keyword)
      return nil
    end

    dist_group = MoanaTypes::DistributeGroup.new
    grp_storage_units = [] of String

    if storage_units["replica"].size > 0 || storage_units["mirror"].size > 0
      grp_storage_units = storage_units["replica"] +
                          storage_units["mirror"] +
                          storage_units["arbiter"]
      dist_group.replica_count = storage_units["replica"].size + \
        storage_units["mirror"].size
      dist_group.arbiter_count = storage_units["arbiter"].size
      dist_group.replica_keyword = replica_keyword(
        storage_units["replica"].size,
        storage_units["mirror"].size
      )
    elsif storage_units["arbiter"].size == 3
      grp_storage_units = storage_units["arbiter"]
      dist_group.replica_count = 3
      dist_group.arbiter_count = 1
    elsif storage_units["disperse"].size > 0 ||
          storage_units["data"].size > 0
      grp_storage_units = storage_units["disperse"] +
                          storage_units["data"] +
                          storage_units["redundancy"]
      dist_group.disperse_count, dist_group.redundancy_count =
        disperse_and_redundancy_count(
          storage_units["disperse"].size,
          storage_units["data"].size,
          storage_units["redundancy"].size
        )
    else
      return nil
    end

    dist_group.storage_units = grp_storage_units.map do |storage_unit|
      hostname, port, path = storage_unit_parse(storage_unit)
      MoanaTypes::StorageUnit.new(hostname, port.to_i, path)
    end

    dist_group
  end

  # Reset the Storage units object before parsing
  # each distribute group
  def self.reset_storage_units
    {
      "replica"    => [] of String,
      "mirror"     => [] of String,
      "arbiter"    => [] of String,
      "disperse"   => [] of String,
      "data"       => [] of String,
      "redundancy" => [] of String,
    }
  end

  # Parse each tokens and construct the Pool Create Request
  def self.parse(args)
    tokens = tokenizer(args)
    req = MoanaTypes::Pool.new
    tokens_iter = tokens.each
    token = next_token(tokens_iter)

    counts = {
      "replica"    => 0,
      "mirror"     => 0,
      "arbiter"    => 0,
      "disperse"   => 0,
      "data"       => 0,
      "redundancy" => 0,
    }
    storage_units = reset_storage_units()
    all_storage_units = [] of String
    skip_token_next = false

    loop do
      break if token.nil?

      case token.kind
      when TokenKind::PoolName    then req.name = token.value
      when TokenKind::StorageUnit then all_storage_units << token.value
      when TokenKind::TypeKeyword
        keyword = token.value
        dist_group = distribute_group(storage_units, keyword)
        unless dist_group.nil?
          req.distribute_groups << dist_group
          storage_units = reset_storage_units()
        end

        loop do
          token = next_token(tokens_iter)
          break if token.nil?

          if token.kind == TokenKind::StorageUnit
            storage_units[keyword] << token.value
            next
          elsif token.kind == TokenKind::Numeric
            counts[keyword] = token.value.to_i
          else
            skip_token_next = true
          end

          break
        end
      end

      unless skip_token_next
        skip_token_next = false
        token = next_token(tokens_iter)
      end
    end

    dist_group = distribute_group(storage_units, nil)
    req.distribute_groups << dist_group unless dist_group.nil?

    if all_storage_units.size > 0
      req.distribute_groups = distribute_group_count_based(
        counts, all_storage_units
      )
    end

    validate(req)

    req
  end

  # Validate the Pool create request after parsing
  def self.validate(req)
    raise InvalidPoolRequest.new("Pool name not specified (Example: mypool)") if req.name == ""
    raise InvalidPoolRequest.new("Atleast one Storage unit is required") if req.distribute_groups.size == 0

    # TODO: Pool name validations

    req.distribute_groups.each do |dist_grp|
      replica_arbiter_dist_grp_size = dist_grp.replica_count
      if dist_grp.arbiter_count > 0 && dist_grp.replica_count == 2
        replica_arbiter_dist_grp_size += 1
      end

      if dist_grp.replica_count > 0 && dist_grp.storage_units.size != replica_arbiter_dist_grp_size
        raise InvalidPoolRequest.new(
          "Number of Storage units not matching #{dist_grp.replica_keyword} count"
        )
      end
      if dist_grp.disperse_count > 0 && dist_grp.storage_units.size != dist_grp.disperse_count
        raise InvalidPoolRequest.new(
          "Number of Storage units not matching disperse count"
        )
      end

      dist_grp.storage_units.each do |storage_unit|
        msg = storage_unit.port > 0 ? "#{storage_unit.port}:" : ""
        msg += storage_unit.path
        raise InvalidPoolRequest.new("Node name is not specified for #{msg}") if storage_unit.node.name == ""
      end
    end
  end
end
