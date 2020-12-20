module XAttr
  class XAttr
    def initialize(path : String)
      @path = path
    end

    def [](key)
      size = bindings.get(@path, key, nil, 0)
      raise_error(size) if size == -1
      return unless size > 0

      ptr = Slice(LibC::Char).new(size)
      res = bindings.get(@path, key, ptr, size)
      raise_error(res) if res == -1

      String.new(ptr)
    end

    def []=(key, value)
      res = bindings.set(@path, key, value, value.bytesize)
      raise_error(res) if res == -1

      res
    end

    def keys
      size = bindings.list(@path, nil, 0)
      raise_error(size) if size == -1
      return [] of String unless size > 0

      ptr = Slice(LibC::Char).new(size)
      bindings.list(@path, ptr, size)

      String.new(ptr).split("\000", remove_empty: true).sort
    end

    def remove(key)
      res = bindings.remove(@path, key)
      raise_error(res) if res == -1

      res
    end

    def each
      keys.each do |k|
        yield k, self.[](k)
      end
    end

    def to_h
      hash = {} of String => String | Nil
      each { |k, v| hash[k] = v }
      hash
    end

    private def raise_error(res)
      raise IO::Error.from_errno("Please check the target file")
    end

    private def bindings
      {% if flag?(:linux) %}
        Platforms::Linux
      {% elsif flag?(:darwin) %}
        Platforms::Darwin
      {% else %}
        {% raise "XAttr Not implemented for this platform" %}
      {% end %}
    end
  end
end
