# eventmachine protocol 
module RTunnel::FrameProtocol
  def receive_data(data)
    @incomplete_frame ||= ''

    i = 0
    loop do
      while @frame_buffer.nil? and i < data.size
        @incomplete_frame << data[i]
        if (data[i] & 0x80) == 0
          @remaining_frame_size = StringIO.new(@incomplete_frame).read_varsize
          @frame_buffer = ''
        end
        i += 1
      end

      return  if @frame_buffer.nil?

      remaining_bytes = data.size - i
      break  if @remaining_frame_size > remaining_bytes

      receive_frame(@frame_buffer + data[i, @remaining_frame_size])
      @incomplete_frame, @frame_buffer = '', nil
      i += @remaining_frame_size
    end

    @frame_buffer << data[i..-1]
    @remaining_frame_size -= data.size-i
  end
  
  def send_frame(frame_data)
    size_str = StringIO.new
    size_str.write_varsize frame_data.length
    send_data size_str.string
    send_data frame_data
  end
end