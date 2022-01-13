require "xml"

struct ImportVolumeData
  property volume_id = "",
    cli_args = [] of String,
    options = Hash(String, String).new
end

# TODO: Fix and remove this warning
# ameba:disable Metrics/CyclomaticComplexity
def from_gluster_volumes_xml(pool_name, data, args)
  parsed = XML.parse(data)
  vols = parsed.xpath_nodes("//volume")

  kadalu_volumes_args = [] of ImportVolumeData
  vols.each do |vol|
    volume_name = ""
    volume_id = ""
    replica_count = 0
    arbiter_count = 0
    disperse_count = 0
    redundancy_count = 0
    volume_state = ""
    vol.children.each do |ele|
      case ele.name
      when "name"
        volume_name = ele.content.strip
      when "id"
        volume_id = ele.content.strip
      when "statusStr"
        volume_state = ele.content.strip
      when "replicaCount"
        replica_count = ele.content.strip.to_i
      when "arbiterCount"
        arbiter_count = ele.content.strip.to_i
      when "disperseCount"
        disperse_count = ele.content.strip.to_i
      when "redundancyCount"
        redundancy_count = ele.content.strip.to_i
      end
    end

    vol_args = ImportVolumeData.new
    vol_args.volume_id = volume_id
    vol_args.cli_args = ["#{pool_name}/#{volume_name}"]

    vol_args.cli_args += ["replica", "#{replica_count}"] if replica_count > 1
    vol_args.cli_args += ["arbiter", "#{arbiter_count}"] if arbiter_count > 0
    vol_args.cli_args += ["disperse", "#{disperse_count}"] if disperse_count > 0
    vol_args.cli_args += ["redundancy", "#{redundancy_count}"] if redundancy_count > 0

    brks = vol.xpath_nodes(".//brick")
    brks.each do |brk|
      hostname = ""
      path = ""
      brk.children.each do |b_ele|
        if b_ele.name == "name"
          hostname, _, path = b_ele.content.strip.rpartition(":")
        end
      end

      node_name = args.volume_args.node_maps.fetch(hostname, hostname)
      vol_args.cli_args << "#{node_name}:#{path}"
    end

    opts = vol.xpath_nodes(".//option")
    opts.each do |opt|
      optname = ""
      optvalue = ""
      opt.children.each do |oele|
        case oele.name
        when "name"
          optname = oele.content.strip
        when "value"
          optvalue = oele.content.strip
        end
      end
      vol_args.options[optname] = optvalue
    end

    kadalu_volumes_args << vol_args
  end

  kadalu_volumes_args
end
