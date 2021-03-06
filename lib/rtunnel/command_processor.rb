# The plumbing for processing RTunnel commands.
module RTunnel::CommandProcessor
  # Called by CommandProtocol to process a command.
  def receive_command(command)
    case @last_command = command
    when RTunnel::CloseConnectionCommand
      process_close_connection command.connection_id
    when RTunnel::CreateConnectionCommand
      process_create_connection command.connection_id
    when RTunnel::GenerateSessionKeyCommand
      process_generate_session_key command.public_key_fp
    when RTunnel::KeepAliveCommand
      process_keep_alive
    when RTunnel::RemoteListenCommand
      process_remote_listen command.address
    when RTunnel::SendDataCommand
      process_send_data command.connection_id, command.data
    when RTunnel::SetSessionKeyCommand
      process_set_session_key command.encrypted_keys
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
  
  # Override to process GenerateSessionKeyCommand. Do NOT call super.  
  def process_generate_session_key(public_key_fp)
    unexpected_command @last_command
  end
  
  # Override to process KeepAliveCommand. Do NOT call super.
  def process_keep_alive
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
  
  # Override to process SetSessionKeyCommand. Do NOT call super.
  def process_set_session_key(encrypted_keys)
    unexpected_command @last_command
  end
  
  # Override to handle commands that haven't been overridden.
  def unexpected_command(command)
      W "Unexpected command: #{command.inspect}"    
  end
end