# eventmachine protocol 
module RTunnel::FrameProtocol
  def receive_data(data)
    @frame_incomplete ||= ''

    i = 0
    loop do
      # read the frame size
      while i < data.length and @frame_buffer.nil?
        @frame_incomplete << data[i]
        # completed frame        
        if (data[i] & 0x80) == 0
          @frame_incomplete = StringIO.new(@frame_incomplete).read_varsize
          @frame_buffer = ''
        end
        i += 1
      end
      
      break unless @frame_buffer
     
      if @frame_incomplete <= data.length - i
        # break off frame
        if @frame_buffer.empty?
          receive_frame data[i, @frame_incomplete]
        else
          receive_frame @frame_buffer + data[i, @frame_incomplete]
        end
        i += @frame_incomplete
        @frame_incomplete, @frame_buffer = '', nil
      else
        # buffer frame fragment
        @frame_buffer << data[i..-1]
        @frame_incomplete -= data.length - i
        break
      end
    end
  end
  
  def send_frame(frame_data)
    size_str = StringIO.new
    size_str.write_varsize frame_data.length
    send_data size_str.string
    send_data frame_data
  end
end