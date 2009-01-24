require 'stringio'

class RTunnel::TruncatedDataError < Exception; end

module RTunnel::IOExtensions
  # writes a size (non-negative Integer) to the stream using a varint encoding
  def write_varsize(size)
    chars = []
    loop do
      size, char = size.divmod(0x80)
      chars << (char | ((size > 0) ? 0x80 : 0))
      break if size == 0
    end
    write chars.pack('C*')
  end
  
  # reads a size (non-negative Integer) from the stream using a varint encoding
  def read_varsize
    size = 0
    multiplier = 1
    loop do
      char = getc
      # TODO(costan): better exception
      unless char
        raise RTunnel::TruncatedDataError.new("Encoded varsize truncated")
      end
      more, size_add = char.divmod(0x80)
      size += size_add * multiplier
      break if more == 0
      multiplier *= 0x80
    end
    size
  end
  
  # writes a string and its length, so it can later be read with read_varstr
  def write_varstring(str)
    write_varsize str.length
    write str
  end
  
  # reads a variable-length string that was previously written with write_varstr
  def read_varstring
    length = read_varsize
    return '' if length == 0
    str = read(length)
    if ! str or str.length != length
      raise RTunnel::TruncatedDataError, "Encoded varstring truncated"
    end
    str
  end
end

IO.send :include, RTunnel::IOExtensions
StringIO.send :include, RTunnel::IOExtensions
