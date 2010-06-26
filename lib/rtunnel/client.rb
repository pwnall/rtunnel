require 'resolv'
require 'timeout'

require 'rubygems'
require 'eventmachine'

class RTunnel::Client
  include RTunnel
  include RTunnel::Logging

  attr_reader :control_address, :control_host, :control_port
  attr_reader :remote_listen_address, :tunnel_to_address
  attr_reader :tunnel_timeout, :private_key
  attr_reader :logger
  attr_reader :connections, :server_connection
  
  def initialize(options = {})
    process_options options
    @connections = {}
    @server_connection = nil
  end

  def start
    return if @server_connection
    @control_host = SocketFactory.host_from_address @control_address
    @control_bind_host = SocketFactory.bind_host_from_address @control_address
    @control_port = SocketFactory.port_from_address @control_address
    connect_to_server
  end
    
  def connect_to_server
    D "Connecting to #{@control_host} port #{@control_port}"
    @server_connection = EventMachine.bind_connect @control_bind_host, nil, @control_host, @control_port,
                                                   Client::ServerConnection, self
  end
  
  def stop
    @connections.each { |connection| connection.close_connection_after_writing }
    
    return unless @server_connection
    @server_connection.close_connection_after_writing
    @server_connection.disable_tunnel_timeouts
    @server_connection = nil
  end
  
  ## option processing
  
  def process_options(options)
    [:control_address, :remote_listen_address, :tunnel_to_address,
     :tunnel_timeout, :private_key].each do |opt|
      instance_variable_set "@#{opt}".to_sym,
          RTunnel::Client.send("extract_#{opt}".to_sym, options[opt])
    end
    
    init_log :level => options[:log_level]    
  end  
  
  def self.extract_control_address(address)
    unless SocketFactory.port_from_address address
      address = "#{address}:#{RTunnel::DEFAULT_CONTROL_PORT}"
    end
    RTunnel.resolve_address address
  end
  
  def self.extract_remote_listen_address(address)
    unless SocketFactory.port_from_address address
      address = "0.0.0.0:#{address}"
    end
    RTunnel.resolve_address address
  end
  
  def self.extract_tunnel_to_address(address)
    address = "localhost:#{address}" if address =~ /^\d+$/    
    RTunnel.resolve_address address
  end
  
  def self.extract_tunnel_timeout(timeout)
    timeout || RTunnel::TUNNEL_TIMEOUT
  end
  
  def self.extract_private_key(key_file)
    key_file and Crypto.read_private_key key_file
  end
end

# Connection to the server's control port.
class RTunnel::Client::ServerConnection < EventMachine::Connection
  # Note: I would've loved to make this a module, but event_machine's
  # connection init order (initialize, connect block, post_init) does not
  # work as advertised (the connect block seems to execute after post_init).
  # So I'm taking the safe route and having my own initialize.
  
  include RTunnel
  include RTunnel::Logging
  include RTunnel::CommandProcessor
  include RTunnel::CommandProtocol
  
  attr_reader :client

  def initialize(client)
    super()
    
    @client = client
    @tunnel_to_address = client.tunnel_to_address
    @tunnel_to_host = SocketFactory.host_from_address @tunnel_to_address
    @tunnel_to_port = SocketFactory.port_from_address @tunnel_to_address
    @timeout_timer = nil
    @hasher = nil
    @connections = @client.connections
    init_log :to => @client
  end

  def post_init
    if @client.private_key
      request_session_key
    else
      request_listen
    end
  end
  
  # Asks the server to open a listen socket for this client's tunnel.
  def request_listen
    send_command RemoteListenCommand.new(@client.remote_listen_address)
    enable_tunnel_timeouts    
  end

  # Asks the server to establish a session key with this client.
  def request_session_key
    D 'Private key provided, asking server for session key'
    key_fp = Crypto.key_fingerprint @client.private_key
    send_command GenerateSessionKeyCommand.new(key_fp)    
  end
  
  def unbind
    # wait for a second, then try connecting again
    W 'Lost server connection, will reconnect in 1s'
    EventMachine.add_timer(1.0) { client.connect_to_server }
    @connections.each { |conn_id, conn| conn.close_connection_after_writing }
    @connections.clear
  end
  
  
  ## Command processing
  
  # CreateConnectionCommand handler
  def process_create_connection(connection_id)
    if @connections[connection_id]
      E "asked to create already open connection #{connection_id}"
      return
    end
    
    D "Tunnel #{connection_id} to #{@tunnel_to_host} port #{@tunnel_to_port}"
    connection = EventMachine.connect(@tunnel_to_host, @tunnel_to_port,
        Client::TunnelConnection, connection_id, @client)
    @connections[connection_id] = connection
  end
  
  # CloseConnectionCommand handler
  def process_close_connection(connection_id)
    if connection = @connections[connection_id]
      I "Closing connection #{connection_id}"
      connection.close_connection_after_writing
      @connections.delete connection_id
    else
      W "Asked to close inexistent connection #{connection_id}"
    end
  end
  # Called when a tunnel connection is closed.
  def data_connection_closed(connection_id)
    return unless @connections.delete(connection_id)
    D "Connection #{connection_id} closed by this end"
    send_command CloseConnectionCommand.new(connection_id)
  end
  
  # SendData handler
  def process_send_data(connection_id, data)
    if connection = @connections[connection_id]
      D "Data: #{data.length} bytes for #{connection_id}"
      connection.tunnel_data data
    else
      W "Received data for non-existent connection #{connection_id}!"
    end
  end

  # SetSessionKey handler
  def process_set_session_key(encrypted_keys)
    case encrypted_keys
    when ''
      W "Sent key to open tunnel server"
      request_listen
    when 'NO'
      if @client.private_key
        E "Server refused provided key"
      else
        E "Server requires authentication and no private key was provided"
      end
      close_connection_after_writing
    else
      D "Received server session keys, installing hashers"
      iokeys = StringIO.new Crypto.decrypt_with_key(client.private_key,
                                                    encrypted_keys)
      @out_hasher = Crypto::Hasher.new iokeys.read_varstring
      @in_hasher = Crypto::Hasher.new iokeys.read_varstring
      self.outgoing_command_hasher = @out_hasher
      self.incoming_command_hasher = @in_hasher
      
      D "Hashers installed, opening listen socket on server"
      request_listen
    end
  end
  
  def receive_bad_frame(frame, exception)
    case exception
    when :bad_signature
      D "Ignoring command with invalid signature"
    when Exception
      D "Ignoring malformed command."
      D "Decoding exception: #{exception.class.name} - #{exception}\n" +
        "#{exception.backtrace.join("\n")}\n"
    end
  end  
  
  ## Connection timeouts.

  # Keep-alive received from the control connection.
  def process_keep_alive
  end  

  #:nodoc:
  def receive_command(command) 
    @last_packet_time = Time.now
    super
  end
    
  # After this is called, the control connection will be closed if no command is
  # received within a certain amount of time.
  def enable_tunnel_timeouts
    @last_packet_time = Time.now
    @timeout_timer = EventMachine::PeriodicTimer.new(1.0) do
      check_tunnel_timeout
    end
  end
  
  # Closes the connection if no command has been received for some time.
  def check_tunnel_timeout
    if tunnel_timeout?
      W 'Tunnel timeout. Disconnecting from server.'
      disable_tunnel_timeouts
      close_connection_after_writing
    end
  end
  
  # Disables timeout checking (so the tunnel will not be torn down if no command
  # is received for some period of time).
  def disable_tunnel_timeouts
    return unless @timeout_timer
    @timeout_timer.cancel
    @timeout_timer = nil
  end

  # If true, a tunnel timeout has occured.
  def tunnel_timeout?
    Time.now - @last_packet_time > client.tunnel_timeout
  end  
end

# A connection to the tunnelled port.
class RTunnel::Client::TunnelConnection < EventMachine::Connection
  include RTunnel
  include RTunnel::Logging
  
  def initialize(connection_id, client)
    super()

    @connection_id = connection_id
    @backlog = ''
    @client = client
    init_log :to => @client
  end
  
  def server_connection
    @client.server_connection
  end
  
  def tunnel_data(data)
    # if the connection hasn't been accepted, store the incoming data until
    # sending can happen
    if @backlog
      @backlog << data
    else
      send_data data
    end
  end
  
  def post_init
    D "Tunnel #{@connection_id} established"
    send_data @backlog unless @backlog.empty?
    @backlog = nil
  end
  
  def receive_data(data)
    D "Data: #{data.length} bytes from #{@connection_id}"
    server_connection.send_command SendDataCommand.new(@connection_id, data)
  end
  
  def unbind
    server_connection.data_connection_closed @connection_id
  end
end
