require "yaml"

CONDITION_MORE_THAN_ONE_SUBVOL = "more_than_one_subvol"

class Graph
  include YAML::Serializable

  property name : String = "", type = "", options : Hash(String, String)? = nil, include_when : String?
end

class VolfileTmpl
  include YAML::Serializable

  property cluster = [] of Graph, volume = [] of Graph, subvol = [] of Graph, brick = [] of Graph
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
    when CONDITION_MORE_THAN_ONE_SUBVOL
      vars["volume.number_of_subvols"].to_i > 1
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
      "volume.name"              => volume.name,
      "volume.id"                => volume.id,
      "volume.type"              => volume.type.downcase,
      "volume.index"             => "#{vidx}",
      "volume.number_of_subvols" => "#{volume.subvols.size}",
    }
  end

  def self.subvol_variables(volume, subvol, vidx, sidx)
    vars = volume_variables volume, vidx
    vars["subvol.type"] = subvol.type.downcase
    vars["subvol.index"] = "#{sidx}"
    vars["subvol.number_of_bricks"] = "#{subvol.bricks.size}"

    # Afr records dirty flag details in xattr.
    # The name of the xattr is <volume-name>-client-<index>
    # These xattrs names are specified as afr-pending-xattr
    # in volfile so that both Client and Self heal
    # daemon will understand. The index starts from zero and
    # will not reset for each sub volume. If a brick is removed,
    # index will not change for existing bricks. When new bricks
    # added it will get new index as len(volinfo.Bricks) + 1
    # TODO: If a subvolume is removed then this may go wrong
    # As a alternative, Brick ID can be used as part of xattr
    # name <volume-name>-client-<brick-id>. But this will break
    # the backward compatibility.
    vars["subvol.afr-pending-xattr"] = ""
    if subvol.type.downcase == "replicate" || subvol.type.downcase == "disperse"
      afr_pending_xattrs = [] of String
      subvol.bricks.each_with_index do |brick, bidx|
        xattr_idx = sidx*subvol.bricks.size + bidx
        afr_pending_xattrs << "#{volume.name}-client-#{xattr_idx}"
      end

      vars["subvol.afr-pending-xattr"] = afr_pending_xattrs.join(",")
    end

    vars
  end

  def self.brick_variables(volume, subvol, brick, vidx, sidx, bidx)
    vars = subvol_variables volume, subvol, vidx, sidx
    vars["brick.node"] = brick.node.hostname
    vars["brick.node_id"] = brick.node.id
    vars["brick.type"] = brick.type.downcase
    vars["brick.path"] = brick.path
    vars["brick.index"] = "#{sidx*subvol.bricks.size + bidx}"
    vars["brick.port"] = "#{brick.port}"

    vars
  end

  def self.cluster_level(name, tmpl, volumes)
    volfile_tmpl = VolfileTmpl.from_yaml(tmpl)

    # Create graph instance with first template element
    graph = Volfile.new(name, volfile_tmpl.cluster[0], Hash(String, String).new, Hash(String, String).new)

    volumes.each_with_index do |volume, vidx|
      opts = volume.options
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

      volume.subvols.each_with_index do |subvol, sidx|
        svars = Volfile.subvol_variables(volume, subvol, 0, sidx)
        sgraph = Volfile.new(name, volfile_tmpl.subvol[0], svars, opts)

        volfile_tmpl.subvol[1..-1].each do |subvol_tmpl|
          if Volfile.include_when?(subvol_tmpl, svars)
            sgraph.add(Volfile.new(name, subvol_tmpl, svars, opts))
          end
        end

        subvol.bricks.each_with_index do |brick, bidx|
          bvars = Volfile.brick_variables(volume, subvol, brick, 0, sidx, bidx)
          bgraph = Volfile.new(name, volfile_tmpl.brick[0], bvars, opts)

          volfile_tmpl.brick[1..-1].each do |brick_tmpl|
            if Volfile.include_when?(brick_tmpl, bvars)
              bgraph.add(Volfile.new(name, brick_tmpl, bvars, opts))
            end
          end

          sgraph.add(bgraph, sibling = true)
        end

        vgraph.add(sgraph, sibling = true)
      end
      if volfile_tmpl.volume.size > 0
        graph.add(vgraph, sibling = true)
      end
    end

    graph.volgen.reverse!.join("\n")
  end

  def self.volume_level(name, tmpl, volume)
    volfile_tmpl = VolfileTmpl.from_yaml(tmpl)

    opts = volume.options

    vvars = Volfile.volume_variables(volume, 0)
    # Create graph instance with first template element
    graph = Volfile.new(name, volfile_tmpl.volume[0], vvars, opts)

    volfile_tmpl.volume[1..-1].each do |vol_tmpl|
      if Volfile.include_when?(vol_tmpl, vvars)
        graph.add(Volfile.new(name, vol_tmpl, vvars, opts))
      end
    end

    volume.subvols.each_with_index do |subvol, sidx|
      svars = Volfile.subvol_variables(volume, subvol, 0, sidx)
      sgraph = Volfile.new(name, volfile_tmpl.subvol[0], svars, opts)

      volfile_tmpl.subvol[1..-1].each do |subvol_tmpl|
        if Volfile.include_when?(subvol_tmpl, svars)
          sgraph.add(Volfile.new(name, subvol_tmpl, svars, opts))
        end
      end

      subvol.bricks.each_with_index do |brick, bidx|
        bvars = Volfile.brick_variables(volume, subvol, brick, 0, sidx, bidx)
        bgraph = Volfile.new(name, volfile_tmpl.brick[0], bvars, opts)

        volfile_tmpl.brick[1..-1].each do |brick_tmpl|
          if Volfile.include_when?(brick_tmpl, bvars)
            bgraph.add(Volfile.new(name, brick_tmpl, bvars, opts))
          end
        end

        sgraph.add(bgraph, sibling = true)
      end

      graph.add(sgraph, sibling = true)
    end

    graph.volgen.reverse!.join("\n")
  end

  def self.brick_level(name, tmpl, volume, brick_id)
    content = ""
    volfile_tmpl = VolfileTmpl.from_yaml(tmpl)
    opts = volume.options

    vvars = Volfile.volume_variables(volume, 0)

    volume.subvols.each_with_index do |subvol, sidx|
      svars = Volfile.subvol_variables(volume, subvol, 0, sidx)

      subvol.bricks.each_with_index do |brick, bidx|
        next if brick.id != brick_id

        bvars = Volfile.brick_variables(volume, subvol, brick, 0, sidx, bidx)
        graph = Volfile.new(name, volfile_tmpl.brick[0], bvars, opts)

        volfile_tmpl.brick[1..-1].each do |brick_tmpl|
          if Volfile.include_when?(brick_tmpl, bvars)
            graph.add(Volfile.new(name, brick_tmpl, bvars, opts))
          end
        end
        content = graph.volgen.reverse!.join("\n")
        break
      end
    end

    content
  end
end
