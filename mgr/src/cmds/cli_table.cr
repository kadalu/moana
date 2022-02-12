enum Align
  Left
  Right
end

class CliTableException < Exception
end

class CliTable
  @rows = [] of Array(String)
  @align = [] of Align
  @max_widths = [] of Int32
  @headers = [] of String

  def initialize(@column_count : Int32)
    @align = (0...@column_count).map { |_| Align::Left }
    @max_widths = (0...@column_count).map { |_| 4 }
  end

  def left_align(column)
    @align[column - 1] = Align::Left
  end

  def right_align(column)
    @align[column - 1] = Align::Right
  end

  def record(*values)
    raise CliTableException.new("Invalid number of Columns") unless values.size == @column_count

    vals = [] of String
    values.each_with_index do |value, idx|
      @max_widths[idx] = "#{value}".size if "#{value}".size > @max_widths[idx]
      vals << "#{value}"
    end

    @rows << vals
  end

  def header(*values)
    raise CliTableException.new("Invalid number of Columns") unless values.size == @column_count
    values.each_with_index do |value, idx|
      @max_widths[idx] = "#{value}".size if "#{value}".size > @max_widths[idx]
      @headers << "#{value}"
    end
  end

  def print_row(values)
    fmt = @align.map_with_index do |align, idx|
      align_char = align == Align::Left ? "-" : ""
      "%#{align_char}#{@max_widths[idx]}s"
    end

    printf("#{fmt.join("  ")}\n", values)
  end

  def render_header
    @headers
  end

  def render_rows
    @rows
  end

  def render
    if @rows.size > 0
      print_row(@headers)
    end

    @rows.each do |row|
      print_row(row)
    end
  end
end
