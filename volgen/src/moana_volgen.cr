require "yaml"

require "./options"

CONDITION_MORE_THAN_ONE_DISTRIBUTE_GROUP = "more_than_one_distribute_group"

class Graph
  include YAML::Serializable

  property name : String = "", type = "", options : Hash(String, String)? = nil, include_when : String?
end

class VolfileTmpl
  include YAML::Serializable

  property pool = [] of Graph, volume = [] of Graph, distribute_group = [] of Graph, storage_unit = [] of Graph
end

def apply_filters(vars)
end

class Volfile
  property name : String, type : String, options : Hash(String, String), subvols : Array(Volfile)
  @last_graph : (Volfile | Nil) = nil

  def initialize(tmpl_name : String, tmpl : Graph, variables : Hash(String, String), options : Hash(String, String))
    @name = tmpl.name
    @type = tmpl.type
    @subvols = [] of Volfile
    @options = Hash(String, String).new
    @tmpl_name = tmpl_name

    opts = Hash(String, String).new

    # If template Options are provided
    if tmpl_opts = tmpl.options
      tmpl_opts.each do |key, value|
        opts[key] = value
      end
    end

    # If type definition also uses template vars
    # Do this before getting opts by type
    variables.each do |key, value|
      @type = @type.sub("{{ #{key} }}", value)
    end

    # Get only options which belongs to current Graph type
    vol_opts = opts_by_type(tmpl_name, tmpl.type, options)
    vol_opts.each do |key, value|
      opts[key] = value
    end

    # Substitute template variables with respective data
    variables.each do |key, value|
      @name = @name.sub("{{ #{key} }}", value)
    end

    # Replace the variable names in each key and value of Options
    newopts = {} of String => String
    opts.each do |optname, optval|
      variables.each do |key, value|
        optname = optname.sub("{{ #{key} }}", value)
        optval = optval.sub("{{ #{key} }}", value)
      end
      newopts[optname] = optval
    end

    @options = newopts
  end

  def subvol_names(graph)
    names = [] of String
    graph.subvols.each do |svol|
      names << svol.name
    end

    names.join(" ")
  end

  def graph_output(graph)
    out = "volume #{graph.name}\n    type #{graph.type}\n"

    if opts = graph.options
      opts.each do |key, value|
        # Add only if option value is not empty
        if value != ""
          out += "    option #{key} #{value}\n"
        end
      end
    end

    out += "    subvolumes #{subvol_names(graph)}\n" if graph.subvols.size > 0
    out += "end-volume\n\n"
  end

  # Recursively render the Volfile graphs and store
  # the output in array
  def volgen(graph)
    graphs = [] of String
    graphs << graph_output(graph)
    graph.subvols.each do |subvol_graph|
      graphs += volgen(subvol_graph)
    end

    graphs
  end

  # Entry point
  def volgen
    volgen self
  end

  def self.include_when?(vol_tmpl, vars)
    case vol_tmpl.include_when
    when CONDITION_MORE_THAN_ONE_DISTRIBUTE_GROUP
      vars["volume.distribute_count"].to_i > 1
    else
      true
    end
  end

  # First time append the Graph to subvols
  # after this add the Graph to last Graph's subvols
  # list. If the input graph is not sibling then replaces
  # the last graph with the current one.
  def add(graph, sibling = false)
    if tmp = @last_graph
      tmp.subvols << graph
    else
      @subvols << graph
    end

    if !sibling
      @last_graph = graph
    end
  end

  def opts_by_type(tmpl_name, graph_type, options)
    opts = Hash(String, String).new
    options.each do |key, value|
      parts = key.split(".")
      if parts.size == 3
        tname = parts[0]
        gtype = parts[1]
        optname = parts[2]
      else
        tname = ""
        gtype = parts[0]
        optname = parts[1]
      end

      # Two ways to detect an option belongs to an Xlator Type
      # <tmpl-name>.<xlator-type>.<opt-name> or
      # <xlator-type>.<opt-name>
      if gtype == graph_type && (tname == "" || tname == tmpl_name)
        opts[optname] = value
      end
    end

    opts
  end

  def self.volume_variables(volume, vidx)
    {
      "volume.name"             => volume.name,
      "volume.id"               => volume.id,
      "volume.type"             => volume.type.downcase.sub("mirror", "replicate"),
      "volume.index"            => "#{vidx}",
      "volume.distribute_count" => "#{volume.distribute_groups.size}",
    }
  end

  def self.distribute_group_variables(volume, dist_grp, vidx, grp_idx)
    vars = volume_variables volume, vidx
    vars["distribute_group.type"] = dist_grp.type.downcase.sub("mirror", "replicate")
    vars["distribute_group.index"] = "#{grp_idx}"
    vars["distribute_group.storage_unit_count"] = "#{dist_grp.storage_units.size}"

    # Afr records dirty flag details in xattr.
    # The name of the xattr is <volume-name>-client-<index>
    # These xattrs names are specified as afr-pending-xattr
    # in volfile so that both Client and Self heal
    # daemon will understand. The index starts from zero and
    # will not reset for each sub volume. If a Storage unit is removed,
    # index will not change for existing storage units. When new storage units
    # added it will get new index as len(volinfo.storage_units) + 1
    # TODO: If a subvolume is removed then this may go wrong
    # As a alternative, Storage Unit ID can be used as part of xattr
    # name <volume-name>-client-<storage-unit-id>. But this will break
    # the backward compatibility.
    vars["distribute_group.afr-pending-xattr"] = ""
    if dist_grp.type.downcase == "replicate" || dist_grp.type.downcase == "disperse"
      afr_pending_xattrs = [] of String
      dist_grp.storage_units.each_with_index do |_, unit_idx|
        xattr_idx = grp_idx*dist_grp.storage_units.size + unit_idx
        afr_pending_xattrs << "#{volume.name}-client-#{xattr_idx}"
      end

      vars["distribute_group.afr-pending-xattr"] = afr_pending_xattrs.join(",")
    end

    vars
  end

  def self.storage_unit_variables(volume, dist_grp, storage_unit, vidx, grp_idx, unit_idx)
    vars = distribute_group_variables volume, dist_grp, vidx, grp_idx
    vars["storage_unit.node"] = storage_unit.node.name
    vars["storage_unit.node_id"] = storage_unit.node.id
    vars["storage_unit.type"] = storage_unit.type.downcase
    vars["storage_unit.path"] = storage_unit.path
    vars["storage_unit.index"] = "#{grp_idx*dist_grp.storage_units.size + unit_idx}"
    vars["storage_unit.port"] = "#{storage_unit.port}"

    vars
  end

  def self.get_expanded_options(opts)
    outopts = Hash(String, String).new
    opts.each do |k, v|
      expanded_opt_names = VolumeOptions.expanded_options(k)
      # Add same value to all the expanded options
      expanded_opt_names.each do |name|
        outopts[name] = v
      end
    end
    outopts
  end

  def self.pool_level(name, tmpl, volumes)
    volfile_tmpl = VolfileTmpl.from_yaml(tmpl)

    # Create graph instance with first template element
    graph = Volfile.new(name, volfile_tmpl.pool[0], Hash(String, String).new, Hash(String, String).new)

    volumes.each_with_index do |volume, vidx|
      opts = get_expanded_options(volume.options)
      vvars = Volfile.volume_variables(volume, vidx)

      vgraph = graph
      if volfile_tmpl.volume.size > 0
        vgraph = Volfile.new(name, volfile_tmpl.volume[0], vvars, opts)
        volfile_tmpl.volume[1..-1].each do |vol_tmpl|
          if Volfile.include_when?(vol_tmpl, vvars)
            vgraph.add(Volfile.new(name, vol_tmpl, vvars, opts))
          end
        end
      end

      volume.distribute_groups.each_with_index do |dist_grp, grp_idx|
        grp_vars = Volfile.distribute_group_variables(volume, dist_grp, 0, grp_idx)
        sgraph = Volfile.new(name, volfile_tmpl.distribute_group[0], grp_vars, opts)

        volfile_tmpl.distribute_group[1..-1].each do |dist_grp_tmpl|
          if Volfile.include_when?(dist_grp_tmpl, grp_vars)
            sgraph.add(Volfile.new(name, dist_grp_tmpl, grp_vars, opts))
          end
        end

        dist_grp.storage_units.each_with_index do |storage_unit, unit_idx|
          unit_vars = Volfile.storage_unit_variables(volume, dist_grp, storage_unit, 0, grp_idx, unit_idx)
          bgraph = Volfile.new(name, volfile_tmpl.storage_unit[0], unit_vars, opts)

          volfile_tmpl.storage_unit[1..-1].each do |storage_unit_tmpl|
            if Volfile.include_when?(storage_unit_tmpl, unit_vars)
              bgraph.add(Volfile.new(name, storage_unit_tmpl, unit_vars, opts))
            end
          end

          sgraph.add(bgraph, sibling: true)
        end

        vgraph.add(sgraph, sibling: true)
      end
      if volfile_tmpl.volume.size > 0
        graph.add(vgraph, sibling: true)
      end
    end

    graph.volgen.reverse!.join("\n")
  end

  def self.volume_level(name, tmpl, volume)
    volfile_tmpl = VolfileTmpl.from_yaml(tmpl)

    opts = get_expanded_options(volume.options)

    vvars = Volfile.volume_variables(volume, 0)
    # Create graph instance with first template element
    graph = Volfile.new(name, volfile_tmpl.volume[0], vvars, opts)

    volfile_tmpl.volume[1..-1].each do |vol_tmpl|
      if Volfile.include_when?(vol_tmpl, vvars)
        graph.add(Volfile.new(name, vol_tmpl, vvars, opts))
      end
    end

    volume.distribute_groups.each_with_index do |dist_grp, grp_idx|
      grp_vars = Volfile.distribute_group_variables(volume, dist_grp, 0, grp_idx)
      sgraph = Volfile.new(name, volfile_tmpl.distribute_group[0], grp_vars, opts)

      volfile_tmpl.distribute_group[1..-1].each do |dist_grp_tmpl|
        if Volfile.include_when?(dist_grp_tmpl, grp_vars)
          sgraph.add(Volfile.new(name, dist_grp_tmpl, grp_vars, opts))
        end
      end

      dist_grp.storage_units.each_with_index do |storage_unit, unit_idx|
        unit_vars = Volfile.storage_unit_variables(volume, dist_grp, storage_unit, 0, grp_idx, unit_idx)
        bgraph = Volfile.new(name, volfile_tmpl.storage_unit[0], unit_vars, opts)

        volfile_tmpl.storage_unit[1..-1].each do |storage_unit_tmpl|
          if Volfile.include_when?(storage_unit_tmpl, unit_vars)
            bgraph.add(Volfile.new(name, storage_unit_tmpl, unit_vars, opts))
          end
        end

        sgraph.add(bgraph, sibling: true)
      end

      graph.add(sgraph, sibling: true)
    end

    graph.volgen.reverse!.join("\n")
  end

  def self.storage_unit_level(name, tmpl, volume, storage_unit_id)
    content = ""
    volfile_tmpl = VolfileTmpl.from_yaml(tmpl)
    opts = get_expanded_options(volume.options)

    # vvars = Volfile.volume_variables(volume, 0)

    volume.distribute_groups.each_with_index do |dist_grp, grp_idx|
      # grp_vars = Volfile.subvol_variables(volume, dist_grp, 0, grp_idx)

      dist_grp.storage_units.each_with_index do |storage_unit, unit_idx|
        next if storage_unit.id != storage_unit_id

        unit_vars = Volfile.storage_unit_variables(volume, dist_grp, storage_unit, 0, grp_idx, unit_idx)
        graph = Volfile.new(name, volfile_tmpl.storage_unit[0], unit_vars, opts)

        volfile_tmpl.storage_unit[1..-1].each do |storage_unit_tmpl|
          if Volfile.include_when?(storage_unit_tmpl, unit_vars)
            graph.add(Volfile.new(name, storage_unit_tmpl, unit_vars, opts))
          end
        end
        content = graph.volgen.reverse!.join("\n")
        break
      end
    end

    content
  end
end
