require 'set'

require 'rubygems'
require 'eventmachine'


# The RTunnel server class, managing control and connection servers.
class RTunnel::Server
  include RTunnel
  include RTunnel::Logging
  include RTunnel::ConnectionId
  
  attr_reader :control_address, :control_host, :control_port
  attr_reader :ping_interval
  attr_reader :tunnel_connections
  
  def initialize(options = {})
    process_options options
    @tunnel_controls = {}
    @tunnel_connections = {}
    @tunnel_connections_by_control = {}
  end
  
  def start
    return if @control_listener
    @control_host = SocketFactory.host_from_address @control_address
    @control_port = SocketFactory.port_from_address @control_address
    start_server
  end
  
  def stop
    return unless @control_listener
    EventMachine::stop_server @control_listener
    @control_listener = nil
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
  def create_tunnel_listener(listen_port, control_connection, &creation_block)
    if old_control = @tunnel_controls[listen_port]
      D "Closing old listener on port #{listen_port}"
      EventMachine::stop_server old_control.listener
    end
    
    EventMachine::next_tick do
      yield
      @tunnel_controls[listen_port] = control_connection
      redirect_tunnel_connections old_control, control_connection if old_control
    end    
  end
  
  # Registers a tunnel connection, so it can receive data.
  def register_tunnel_connection(connection)
    @tunnel_connections[connection.connection_id] = connection
    control_connection = connection.control_connection
    @tunnel_connections_by_control[control_connection] ||= Set.new
    @tunnel_connections_by_control[control_connection] << connection
  end
  
  # De-registers a tunnel connection.
  def deregister_tunnel_connection(connection)
    @tunnel_connections.delete connection.connection_id
    control_connection = connection.control_connection
    @tunnel_connections_by_control[control_connection].delete connection
  end
  
  def redirect_tunnel_connections(old_control, new_control)
    return unless old_connections = @tunnel_connections_by_control[old_control]
    old_connections.each do |tunnel_connection|
      tunnel_connection.control_connection = new_control
    end
    @tunnel_connections_by_control[new_control] ||= Set.new
    @tunnel_connections_by_control[new_control] += old_connections
  end
  
  ## option processing
  
  def process_options(options)
    [:control_address, :ping_interval].each do |opt|
      instance_variable_set "@#{opt}".to_sym,
          RTunnel::Server.send("extract_#{opt}".to_sym, options[opt])
    end
    
    init_log :level => options[:log_level]    
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

  attr_reader :server, :listener
  
  def initialize(server)
    super()
    
    @server = server
    @tunnel_connections = server.tunnel_connections
    @listener = nil
    @peer_name = nil
    
    init_log :to => @server
  end
  
  def post_init
    @client_port, @client_host = *Socket.unpack_sockaddr_in(get_peername)
    D "Established connection with #{@client_host} port #{@client_port}"
    enable_pinging
  end
  
  def unbind
    D "Lost connection from #{@client_host} port #{@client_port}"
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
    
    @server.create_tunnel_listener listen_port, self do
      D "Creating listener for #{listen_host} port #{listen_port}"
      @listener = EventMachine::start_server listen_host, listen_port,
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
  attr_accessor :control_connection
  
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
    close_connection_after_writing
  end
  
  def receive_data(data)
    D "Data: #{data.length} bytes for #{@connection_id}"
    @control_connection.send_command SendDataCommand.new(@connection_id, data)
  end
end