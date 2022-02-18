require "./helpers"

struct VolfileArgs
  property output_file = ""
end

class Args
  property volfile_args = VolfileArgs.new
end

VOLFILE_GET_BANNER = "
Usage: kadalu volfile get NAME POOL [arguments]
       kadalu volfile get NAME POOL/VOLUME [arguments]
       kadalu volfile get NAME POOL/VOLUME STORAGE_UNIT [arguments]
"

command "volfile.get", "Get Kadalu Storage Volfile" do |parser, args|
  parser.banner = VOLFILE_GET_BANNER
  parser.on("-o FILE", "--output-file=FILE", "Output file path") do |outfile|
    args.volfile_args.output_file = outfile
  end
end

handler "volfile.get" do |args|
  tmpl = args.pos_args.size > 0 ? args.pos_args[0] : ""
  pool_volume = args.pos_args.size > 1 ? args.pos_args[1] : ""
  args.pool_name, _, volume = pool_volume.partition("/")
  storage_unit = args.pos_args.size > 2 ? args.pos_args[2] : ""

  command_error "Volfile Template name is required" if tmpl == ""
  command_error "Pool name is required" if args.pool_name == ""

  if args.volfile_args.output_file != ""
    command_error "Output file exists" if File.exists?(args.volfile_args.output_file)

    parent_dir = Path[args.volfile_args.output_file].parent
    command_error "Directory(#{parent_dir}) not exists" unless File.exists?(parent_dir)
  end

  api_call(args, "Failed to generate the Volfile") do |client|
    if storage_unit != "" && volume != ""
      # Storage Unit level Volfile
      volfile = client.pool(args.pool_name).volume(
        volume).get_volfile(tmpl, storage_unit)
    elsif volume == ""
      # Pool level Volfile
      volfile = client.pool(args.pool_name).get_volfile(
        tmpl)
    else
      # Volume level Volfile
      volfile = client.pool(args.pool_name).volume(
        volume).get_volfile(tmpl)
    end

    handle_json_output(volfile, args)

    if args.volfile_args.output_file == ""
      puts volfile.content
    else
      File.write(args.volfile_args.output_file, volfile.content)
      puts "Volfile generated successfully"
      puts args.volfile_args.output_file
    end
  end
end
