module XAttr
  module Platforms
    module Linux
      lib LibXAttr
        {% if flag?(:linux) %}
          fun getxattr(path : LibC::Char*, name : LibC::Char*, value : LibC::Char*, size : LibC::SizeT) : LibC::Int
          fun setxattr(path : LibC::Char*, name : LibC::Char*, value : LibC::Char*, size : LibC::SizeT, options : LibC::Int) : LibC::Int
          fun listxattr(path : LibC::Char*, list : LibC::Char*, size : LibC::SizeT) : LibC::Int
          fun removexattr(path : LibC::Char*, name : LibC::Char*) : LibC::Int
        {% end %}
      end

      def self.get(path, key, value, size)
        LibXAttr.getxattr(path, key, value, size)
      end

      def self.set(path, key, value, size)
        LibXAttr.setxattr(path, key, value, value.bytesize, 0)
      end

      def self.list(path, list, size)
        LibXAttr.listxattr(path, list, size)
      end

      def self.remove(path, key)
        LibXAttr.removexattr(path, key)
      end
    end
  end
end
