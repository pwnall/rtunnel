# eventmachine protocol 
module RTunnel::FrameProtocol
  def receive_data(data)
    @frame_size_buffer ||= ''

    i = 0
    loop do
      while @frame_buffer.nil? and i < data.size
        @frame_size_buffer << data[i]
        if (data[i] & 0x80) == 0
          @remaining_frame_size = StringIO.new(@frame_size_buffer).read_varsize
          @frame_buffer = ''
        end
        i += 1
      end

      return  if @frame_buffer.nil?
      break  if @remaining_frame_size > data.size - i

      receive_frame(@frame_buffer + data[i, @remaining_frame_size])
      @frame_size_buffer, @frame_buffer = '', nil
      i += @remaining_frame_size
    end

    @frame_buffer << data[i..-1]
    @remaining_frame_size -= data.size-i
  end

  def send_frame(frame_data)
    size_str = StringIO.new
    size_str.write_varsize(frame_data.length)
    send_data(size_str.string + frame_data)
  end
end