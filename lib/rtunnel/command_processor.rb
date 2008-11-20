# The plumbing for processing RTunnel commands.
module RTunnel::CommandProcessor
  # Called by CommandProtocol to process a command.
  def receive_command(command)
    case @last_command = command
    when RTunnel::CloseConnectionCommand
      process_close_connection command.connection_id
    when RTunnel::CreateConnectionCommand
      process_create_connection command.connection_id      
    when RTunnel::PingCommand
      process_ping
    when RTunnel::RemoteListenCommand
      process_remote_listen command.address
    when RTunnel::SendDataCommand
      process_send_data command.connection_id, command.data
    end
  end

  # Override to process CloseConnectionCommand. Do NOT call super.
  def process_close_connection(connection_id)
    unexpected_command @last_command
  end

  # Override to process CreateConnectionCommand. Do NOT call super.
  def process_create_connection(connection_id)
    unexpected_command @last_command
  end
  
  # Override to process PingCommand. Do NOT call super.
  def process_ping
    unexpected_command @last_command
  end

  # Override to process RemoteListenCommand. Do NOT call super.
  def process_remote_listen(address)
    unexpected_command @last_command
  end

  # Override to process SendDataCommand. Do NOT call super.
  def process_send_data(connection_id, data)
    unexpected_command @last_command
  end
  
  # Override to handle commands that haven't been overridden.
  def unexpected_command(command)
      W "Unexpected command: #{command.inspect}"    
  end
end