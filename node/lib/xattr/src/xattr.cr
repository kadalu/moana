require "./xattr/**"

# Crystal bindings to XATTR.
# This library allows to manage extended file attributes (XATTR) as file metadata.
module XAttr
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}

  def self.new(path : String)
    XAttr.new(path)
  end
end
