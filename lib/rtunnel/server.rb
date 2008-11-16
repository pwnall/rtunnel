require 'set'

require 'rubygems'
require 'eventmachine'
require 'uuidtools'


# The RTunnel server class, managing control and connection servers.
class RTunnel::Server
  include RTunnel
  include RTunnel::Logging
  
  attr_reader :control_address, :control_host, :control_port
  attr_reader :ping_interval
  attr_reader :tunnel_connections
  
  def initialize(options = {})
    process_options options
    @tunnel_listeners = {}
    @tunnel_connections = {}
    
    init_log
  end
  
  def start
    @control_host = SocketFactory.host_from_address @control_address
    @control_port = SocketFactory.port_from_address @control_address
    start_server
  end
  
  def stop
    return unless @control_listener
    EventMachine::stop_server @control_listener
  end
  
  def start_server
    D "Control server on #{@control_host} port #{@control_port}"
    @control_listener = EventMachine::start_server @control_host, @control_port,
                                                   Server::ControlConnection,
                                                   self
  end
  
  # Creates a listener on a certain port. The given block should create and
  # return the listener. If a listener is already active on the given port,
  # the current listener is closed, and the new listener is created after the
  # old listener is closed.
  def create_tunnel_listener(listen_port, &creation_block)
    # TODO(victor): implement this correctly
    @tunnel_listeners[listen_port] = yield
  end
  
  # Creates a string ID that is guaranteed to be unique across the server,
  # and hard to guess.
  def new_connection_id
    # TODO(not_me): UUIDs don't have 128 bits of entropy, because they
    #               contain the MAC, etc; upgrade to encrypting sequence numbers
    #               with an AES key generated @ server startup
    UUID.timestamp_create.hexdigest
  end

  # Registers a tunnel connection, so it can receive data.
  def register_tunnel_connection(connection)
    @tunnel_connections[connection.connection_id] = connection
  end
  
  # De-registers a tunnel connection.
  def deregister_tunnel_connection(connection)
    @tunnel_connections.delete connection.connection_id
  end
  
  
  ## option processing
  
  def process_options(options)
    [:control_address, :ping_interval].each do |opt|
      instance_variable_set "@#{opt}".to_sym,
          RTunnel::Server.send("extract_#{opt}".to_sym, options[opt])
    end
  end

  def self.extract_control_address(address)
    return "0.0.0.0:#{RTunnel::DEFAULT_CONTROL_PORT}" unless address
    host, port = address.split(':', 2)
    host = RTunnel.resolve_address(host || "0.0.0.0")
    port ||= RTunnel::DEFAULT_CONTROL_PORT.to_s
    return "#{host}:#{port}"
  end
  
  def self.extract_ping_interval(interval)
    interval || RTunnel::PING_INTERVAL
  end   
end


# A client connection to the server's control port.
class RTunnel::Server::ControlConnection < EventMachine::Connection
  include RTunnel
  include RTunnel::CommandProtocol
  include RTunnel::Logging

  attr_reader :server
  
  def initialize(server)
    super()
    
    @server = server
    @tunnel_connections = server.tunnel_connections
    
    init_log :to => @server
  end
  
  def post_init
    D "Established connection with #{Socket.unpack_sockaddr_in(get_peername)}"
    enable_pinging
  end
  
  def unbind
    disable_pinging
  end
  
  
  ## Command processing
  
  def receive_command(command)
    case command
    when RemoteListenCommand
      process_remote_listen(command.address)
    when SendDataCommand
      process_send_data(command.connection_id, command.data)
    when CloseConnectionCommand
      process_close_connection(command.connection_id)
    else
      W "Unexpected command: #{command.inspect}"
    end
  end
  
  def process_remote_listen(address)
    listen_host = SocketFactory.host_from_address address
    listen_port = SocketFactory.port_from_address address
    
    D "Creating listener for #{listen_host} port #{listen_port}"
    @server.create_tunnel_listener listen_port do
      EventMachine::start_server listen_host, listen_port,
                                 Server::TunnelConnection, self,
                                 listen_host, listen_port
    end
    
    D "Listening on #{listen_host} port #{listen_port}"
  end
  
  def process_send_data(tunnel_connection_id, data)    
    tunnel_connection = @tunnel_connections[tunnel_connection_id]
    if tunnel_connection
      D "Data: #{data.length} bytes coming from #{tunnel_connection_id}"
      tunnel_connection.send_data data
    else
      W "Asked to send to unknown connection #{tunnel_connection_id}"
    end
  end
  
  def process_close_connection(tunnel_connection_id)
    tunnel_connection = @tunnel_connections[tunnel_connection_id]
    if tunnel_connection
      D "Closed from tunneled end: #{tunnel_connection_id}"
      tunnel_connection.close_from_tunnel
    else
      W "Asked to close unkown connection #{tunnel_connection_id}"
    end
  end
  
  
  ## Pinging
  
  # Enables sending PingCommands every few seconds.
  def enable_pinging
    @ping_timer = EventMachine::PeriodicTimer.new 2.0 do
      send_command PingCommand.new
     end
  end
  
  # Disables processing of ping timeouts.
  def disable_pinging
    return unless @ping_timer
    @ping_timer.cancel
    @ping_timer = nil
  end  
end


# A connection to a tunnelled port.
class RTunnel::Server::TunnelConnection < EventMachine::Connection
  include RTunnel
  include RTunnel::Logging
  
  attr_reader :connection_id
  
  def initialize(control_connection, listen_host, listen_port)
    # listen_host and listen_port are passed for logging purposes only
    @listen_host = listen_host
    @listen_port = listen_port
    @control_connection = control_connection
    @server = @control_connection.server
    
    init_log :to => @server
  end
  
  def post_init
    @connection_id = @server.new_connection_id
    peer = Socket.unpack_sockaddr_in get_peername
    D "Tunnel from #{peer} on #{@connection_id}"
    @server.register_tunnel_connection self
    @control_connection.send_command CreateConnectionCommand.new(@connection_id)
  end
  
  def unbind
    unless @tunnel_closed
      D "Closed from client end: #{@connection_id}"
      close_command = CloseConnectionCommand.new(@connection_id)
      @control_connection.send_command close_command
    end
    @server.deregister_tunnel_connection self
  end
  
  def close_from_tunnel
    @tunnel_closed = true
    close_after_writing
  end
  
  def receive_data(data)
    D "Data: #{data.length} bytes for #{@connection_id}"
    @control_connection.send_command SendDataCommand.new(@connection_id, data)
  end
end