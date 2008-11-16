require 'resolv'
require 'thread'
require 'timeout'

require 'rubygems'
require 'eventmachine'

class RTunnel::Client
  include RTunnel
  include RTunnel::Logging

  attr_reader :control_address, :control_host, :control_port
  attr_reader :remote_listen_address, :tunnel_to_address
  attr_reader :ping_timeout
  attr_reader :logger
  attr_reader :server_connection
  
  def initialize(options = {})
    process_options options
    
    init_log
  end

  def start
    @control_host = SocketFactory.host_from_address @control_address
    @control_port = SocketFactory.port_from_address @control_address
    connect_to_server
  end
    
  def connect_to_server
    D "Connecting to #{@control_host} port #{@control_port}"
    @server_connection = EventMachine::connect @control_host, @control_port,
                                               Client::ServerConnection, self
  end
  
  ## option processing
  
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
  
  def self.extract_ping_timeout(timeout)
    timeout || RTunnel::PING_TIMEOUT
  end

  def process_options(options)
    [:control_address, :remote_listen_address, :tunnel_to_address,
     :ping_timeout].each do |opt|
      instance_variable_set "@#{opt}".to_sym,
          RTunnel::Client.send("extract_#{opt}".to_sym, options[opt])
    end
  end  
end

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


class RTunnel::Client::ServerConnection < EventMachine::Connection
  # Note: I would've loved to make this a module, but event_machine's
  # connection init order (initialize, connect block, post_init) does not
  # work as advertised (the connect block seems to execute after post_init).
  # So I'm taking the safe route and having my own initialize.
  
  include RTunnel
  include RTunnel::Logging
  include RTunnel::CommandProtocol
  
  attr_reader :client

  def initialize(client)
    super()
    
    @client = client
    @tunnel_to_address = client.tunnel_to_address
    @tunnel_to_host = SocketFactory.host_from_address @tunnel_to_address
    @tunnel_to_port = SocketFactory.port_from_address @tunnel_to_address
    @ping_timer = nil
    @connections = {}
    init_log :to => @client
  end

  def post_init
    send_command RemoteListenCommand.new(@client.remote_listen_address)
    enable_ping_timeouts
  end
  
  def unbind
    # wait for a second, then try connecting again
    W 'Lost server connection, will reconnect in 1s'
    EventMachine::add_timer(1.0) { client.connect_to_server }
  end
  
  # Perform one command coming from the control connection. 
  def receive_command(command)
    case command
    when PingCommand
      process_ping
    when CreateConnectionCommand
      process_create_connection command.connection_id      
    when CloseConnectionCommand
      process_close_connection command.connection_id
    when SendDataCommand
      process_send_data command.connection_id, command.data
    end
  end

  # CreateConnectionCommand handler
  def process_create_connection(connection_id)
    if @connections[connection_id]
      E "asked to create already open connection #{connection_id}"
      return
    end
    
    D "Tunnel #{connection_id} to #{@tunnel_to_host} port #{@tunnel_to_port}"
    connection = EventMachine::connect(@tunnel_to_host, @tunnel_to_port,
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
  
  # Acknowledge a ping received from the control connection.
  def process_ping
    @last_ping = Time.now
  end  
  
  # After this is called, the control connection will be closed if no
  # PingCommand is received within a certain amount of time.
  def enable_ping_timeouts
    @last_ping = Time.now
    @ping_timer = EventMachine::PeriodicTimer.new 1.0 do
       if ping_timeout?
         W 'Ping timeout. Disconnecting from server.'
         disable_ping_timeouts
         close_connection_after_writing
       end
     end
  end
  
  # Disables processing of ping timeouts.
  def disable_ping_timeouts
    return unless @ping_timer
    @ping_timer.cancel
    @ping_timer = nil
  end

  # If true, a ping timeout has occured.
  def ping_timeout?
    return Time.now - @last_ping > client.ping_timeout
  end  
end


class RTunnel::Client::TunnelConnection < EventMachine::Connection
  include RTunnel
  include RTunnel::Logging
  
  def initialize(connection_id, client)
    super()

    @connection_id = connection_id
    @backlog = ''
    @client = client
    @server_connection = client.server_connection
    init_log :to => @client
  end
  
  def tunnel_data(data)
    # if the connection hasn't been accepted, store the incoming data until
    # sending can happen
    if @backlog
      @backlog += data
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
    D "Data: #{data.length} from #{@connection_id}"
    @server_connection.send_command SendDataCommand.new(@connection_id, data)
  end
  
  def unbind
    @server_connection.data_connection_closed @connection_id
  end
end

class RTunnel::Client0
  
  ## control connection management

  def spawn_main_thread
    @main_thread = logged_thread do
      thread_killer = @thread_killer
      loop do
        break if thread_killer[0]        
        disable_ping_timeouts
        unless connect_control_sock
          sleep 1
          next
        end
        enable_ping_timeouts

        break if thread_killer[0]        
        send_listen_command
        
        break if thread_killer[0]        
        process_commands
      end
      close_all_connections      
    end
  end
  
  # Loop and process commands coming from the control connection.
  def process_commands
    cmd_queue = ThreadedIOString.new
    spawn_control_sock_reader cmd_queue
    
    while !@thread_killer[0] && (command = Command.decode(cmd_queue))
      process_command command
    end
  end
  
  
  # Connect the control socket to the control address on the server.
  def connect_control_sock
    I "connecting to control address (#{@control_address})"
    @control_sock = begin
      timeout(5) do
        socket :out_addr => @control_address, :no_delay => true
      end
    rescue Timeout::Error
      W "timeout connecting to control address"
      return false
    rescue SystemCallError
      W "connect() failure while connecting to control address"
      return false
    end
    return true
  end
  
  
  ## connection management
    
  # Close all the port forwarding connections (not the control connection.)
  def close_all_connections
    connection_ids = @connections_lock.synchronize { @connections.keys }
    connection_ids.each { |connection_id| close_connection connection_id }
  end

end
