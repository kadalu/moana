module VolumeOptions
  extend self

  class Option
    property expanded_options = [] of String,
      validation = "",
      min = 0,
      max = 0,
      choices = [] of String
  end

  class_property options = Hash(String, Option).new

  def validate_bool(value)
    ["on", "off", "enable", "disable", "true", "false"].includes?(value.downcase)
  end

  def valid_option?(name, value)
    opt = @@options[name]?
    return false if opt.nil?

    if opt.validation == "bool"
      return validate_bool(value)
    end

    # No validation defined
    true
  end

  def expanded_options(name)
    opt = @@options[name]?
    opt.nil? ? [name] : opt.expanded_options
  end

  def add_bool_option(name : String, &block : Option -> Nil)
    opt = Option.new
    block.call(opt)
    @@options[name] = opt
  end

  add_bool_option "feature.simple-quota-pass-through" do |opt|
    opt.validation = "bool"
    opt.expanded_options = [
      "features/simple-quota.pass-through",
    ]
  end
end
