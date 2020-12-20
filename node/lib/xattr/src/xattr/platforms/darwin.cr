module XAttr
  module Platforms
    module Darwin
      lib LibXAttr
        {% if flag?(:darwin) %}
          fun getxattr(path : LibC::Char*, name : LibC::Char*, value : LibC::Char*, size : LibC::SizeT, position : LibC::UInt32T, options : LibC::Int) : LibC::Int
          fun setxattr(path : LibC::Char*, name : LibC::Char*, value : LibC::Char*, size : LibC::SizeT, position : LibC::UInt32T, options : LibC::Int) : LibC::Int
          fun listxattr(path : LibC::Char*, list : LibC::Char*, size : LibC::SizeT, options : LibC::Int) : LibC::Int
          fun removexattr(path : LibC::Char*, name : LibC::Char*, options : LibC::Int) : LibC::Int
        {% end %}
      end

      def self.get(path, key, value, size)
        LibXAttr.getxattr(path, key, value, size, 0, 0)
      end

      def self.set(path, key, value, size)
        LibXAttr.setxattr(path, key, value, value.bytesize, 0, 0)
      end

      def self.list(path, list, size)
        LibXAttr.listxattr(path, list, size, 0)
      end

      def self.remove(path, key)
        LibXAttr.removexattr(path, key, 0)
      end
    end
  end
end
