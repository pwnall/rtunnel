module RTunnel::CommandProtocol  
  include RTunnel::FrameProtocol
  
  # Sends an encoded RTunnel command as a frame.
  def send_command(command)
    send_frame command.to_encoded_str
  end
  
  # Decodes a frame into an RTunnel command.
  def receive_frame(frame)
    command = RTunnel::Command.decode StringIO.new(frame)
    receive_command command
  end  
end
