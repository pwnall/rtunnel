require 'thread'

class RTunnel::TruncatedDataError < Exception
  attr_reader :data
  def initialize(data)
    super('A stream contained less data than expected')
    @data = data
  end
end

class RTunnel::StringBuffer
  def initialize(initial_value = "")
    # data gets read from here
    @string = initial_value
    @read_offset = 0
    
    clear_strings!
  end
  
  def append(string)
    @strings << string
    @strings_bytes += string.length
  end
  
  def bytes_available
    @strings_bytes + @string.length - @read_offset
  end
  
  def empty?
    bytes_available == 0
  end
     
  # reads n bytes, returns nil if n bytes are not available
  def read_n(n)
    return nil if bytes_available < n
    truncate_string! if @read_offset * 2 > @string.length
    merge_strings! if @string.length < n
    
    return_value = @string[@read_offset, n]
    @read_offset += n
    return_value
  end
  
  # merges the strings in the append queue, for easy reading 
  def merge_strings!(wanted_bytes = -1)
    @strings[0] = @string
    @string = @strings.join ''
    clear_strings!
  end
  private :merge_strings!
  
  # drops the part of @string that was already read
  def truncate_string!
    return if @read_offset == 0
    @string = @string[@read_offset..-1]
    @read_offset = 0
  end
  private :truncate_string!
  
  def clear_strings!
    # append() appends to this array
    @strings = [nil]
    @strings_bytes = 0
  end
  private :clear_strings!
end

# Implements a subset of the IO interface on top of a StringBuffer
module RTunnel::IO_StringBuffer  
  def <<(string)
    append string
  end
  
  def write(string)
    append string
  end
  
  def getc
    byte = read(1)
    byte ? byte[0] : nil
  end
  
  def putc(char)
    append char.kind_of?(Numeric) ? char.chr : char[0, 1]
  end
  
  def read(length = nil, buffer = nil)
    if bytes_available == 0
      return length ? nil : ''
    end
    
    read_length = [length || bytes_available, bytes_available].min
    return_val = read_n(read_length)
    buffer.replace return_val if buffer
    
    return_val
  end
  
  def eof?
    empty?
  end
end

# StringBuffer tailored for a threaded producer/consumer scenario
class RTunnel::ThreadedStringBuffer < RTunnel::StringBuffer
  def initialize(string = "")
    super
    @append_notice = ConditionVariable.new
    @append_lock = Mutex.new
    @closed = false
  end
  
  # closes the writer's end of the buffer
  def writer_close
    @append_lock.synchronize do
      @closed = true
      @append_notice.signal
    end
  end
  
  def append(string)
    @append_lock.synchronize do
      super
      @append_notice.signal
    end
  end
  
  def read_n(n)
    @append_lock.synchronize do
      wait_for_n n, false unless @closed
      super
    end
  end
  
  def wait_for_n(n, do_synchronize = true)
    if do_synchronize
      @append_lock.synchronize do
        wait_for_n n, false
      end
    else
      while bytes_available < n
        break if @closed
        @append_notice.wait @append_lock
      end      
    end
  end
end


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
      raise RuntimeError, "Encoded varint truncated" unless char
      more, size_add = char.divmod(0x80)
      size += size_add * multiplier
      return size if more == 0
      multiplier *= 0x80
    end
    return size
  end
  
  # writes a string and its length, so it can later be read with read_varstr
  def write_varstring(str)
    write_varsize str.length
    write str
  end
  
  # reads a variable-length string that was previously written with write_varstr
  def read_varstring
    length = read_varsize
    str = read length
    return '' if length == 0
    if !str || str.length != length
      # TODO(costan): better exception
      raise RuntimeError, "Variable-length string was truncated"
    else
      return str
    end
  end
end

class RTunnel::IOString < RTunnel::StringBuffer
  include RTunnel::IO_StringBuffer
  include RTunnel::IOExtensions
end

class RTunnel::ThreadedIOString < RTunnel::ThreadedStringBuffer
  include RTunnel::IO_StringBuffer
  include RTunnel::IOExtensions
  
  def read(length = nil, buffer = nil)
    wait_for_n length if length
    super
  end
end

RTunnel::IOString.send :include, RTunnel::IOExtensions
IO.send :include, RTunnel::IOExtensions
