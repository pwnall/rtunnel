module RTunnel::CommandProtocol  
  include RTunnel::FrameProtocol
  
  # Sends an encoded RTunnel command as a frame.
  def send_command(command)    
    command_str = command.to_encoded_str
    if @command_hasher
      send_frame command_str + @command_hasher.hash(command_str)
    else
      send_frame command_str
    end
  end
  
  # Decodes a frame into an RTunnel command.
  def receive_frame(frame)
    ioframe = StringIO.new frame
    begin
      command = RTunnel::Command.decode ioframe
    rescue Exception => e
      receive_bad_frame frame, e
      return
    end
    if @command_hasher
      signature = ioframe.read
      if signature != @command_hasher.hash(frame[0...(-signature.length)])
        receive_bad_frame frame, :bad_signature
        return
      end
    end
    receive_command command
  end
  
  # Sets a cryptographic hasher that will be used to sign and verify commands.
  # Once a hasher is set, all outgoing frames will be signed, and all incoming
  # frames without a matching signature will be ignored.
  def command_hasher=(hasher)
    @command_hasher = hasher    
  end
  
  # Override to handle frames with corrupted or absent signatures.
  def receive_bad_frame(frame, exception)
    
  end
end