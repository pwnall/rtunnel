require 'rubygems'
gem 'uuidtools', '>=1.0.2'
require 'uuidtools'

class RTunnel::AbstractServer
  include RTunnel::SocketFactory
  include RTunnel::Logging
  
  
  ## public interface
  
  def initialize(address)
    @listen_socket = socket :in_addr => address, :no_delay => true
    @connections_lock = Mutex.new
    @connections = {}
    @connections_next_id = 1
    @main_thread = nil
    
    init_log
  end
    
  # Start the server. The processing will happen in another thread. 
  def start
    @main_thread = spawn_connection_accepter
    self
  end

  # Stop all the threads and close all the connections.
  def stop
    @listen_socket.close
    close_all_connections
    self
  end
  
  # Block until the server is stopped.
  def join
    @main_thread.join if @main_thread
  end
  
  
  ## protected methods
  
  # Spawn a thread that accepts connections from the listen socket and calls
  # incoming_connections on them.
  # The 
  def spawn_connection_accepter
    logged_thread do
      @listen_socket.listen 1024
      begin 
        loop do
          conn_socket, conn_sock_addr = @listen_socket.accept
          incoming_connection conn_socket, conn_sock_addr
        end
      rescue IOError
        # we closed the socket
      end      
    end    
  end

  # Process an incoming connection.
  def incoming_connection(socket, socket_address)
    D "new incoming connection from " +
        Socket.unpack_sockaddr_in(socket_address).inspect
    conn = register_connection socket
    D "connection from " +
        Socket.unpack_sockaddr_in(socket_address).inspect +
        " received ID #{conn[:id]}"
    spawn_connection_threads conn
    return conn
  end
  
  # Spawn the threads for processing an incoming connection.
  def spawn_connection_threads(connection)
    spawn_reader connection
    spawn_writer connection
  end
    
  # Register a new incoming connection.
  def register_connection(socket)
    conn = new_connection socket
    @connections_lock.synchronize { @connections[conn[:id]] = conn }
    return conn
  end

  # Stop keeping track of an incoming connection.
  def deregister_connection(connection_id)
    @connections_lock.synchronize { @connections.delete connection_id }
  end

  # Close an incoming connection.
  def close_connection(connection_id)
    return nil unless connection = deregister_connection(connection_id)
    connection[:queue] << nil        
    connection[:sock].close rescue nil
    connection
  end
  
  def close_all_connections
    connection_ids = @connections_lock.synchronize { @connections.keys }
    connection_ids.each { |connection_id| close_connection connection_id }
  end

  # Create the data needed to keep track of a new connection.
  def new_connection(socket)
    { :id => new_connection_id, :queue => Queue.new, :sock => socket }
  end
  
  # Generate an ID for a new connection.
  def new_connection_id
    @connections_lock.synchronize do
      new_id = @connections_next_id
      @connections_next_id += 1
      new_id
    end
  end  

  # Spawn a thread that reads incoming data from a socket and yields the data
  # as it arrives.
  def spawn_socket_reader(socket, &data_processor)
    logged_thread do
      begin
        loop do
          data = socket.readpartial 16384
          yield data      
        end
      rescue IOError => e
        # we closed the socket
      rescue Errno::ECONNRESET, EOFError => e
        D "client disconnected (#{e.class.name})"
        yield nil
        break
      end
    end
  end

  # Spawn a thread that reads incoming data from a connection and calls
  # inbound_data when data arrives.
  # The thread is stopped by closing the connection.
  def spawn_reader(connection)
    spawn_socket_reader connection[:sock] do |data|
      data ? inbound_data(connection, data) : closed_connection(connection)
    end
  end
  
  # Spawn a thread that moves data from a connection's outbound queue to its
  # socket.
  # The thread is stopped by enqueuing a nil to the outbound queue.
  def spawn_writer(connection)
    logged_thread do
      socket = connection[:sock]
      queue = connection[:queue]
      begin
        loop do
          data = queue.pop
          break unless data
          socket.write data
        end
      rescue Errno::EPIPE
        # other end disappeared without disconnecting cleanly
        D "broken pipe on #{connection[:id]}"
      end
      closed_connection connection
      D "writer thread done on connection #{connection[:id]}"
    end
  end
  
  # Queue data to be sent through a connection.
  def enqueue_outbound_data(connection_id, data)
    connection = @connections_lock.synchronize { @connections[connection_id] }
    if connection
      connection[:queue].push data
    else
      W "request to send data to unknown connection #{connection_id}"
    end
  end
  
  def closed_connection(connection)
    close_connection connection
  end
end

class RTunnel::RemoteListenServer < RTunnel::AbstractServer
  include RTunnel
  
  def initialize(address, control_queue)
    super(address)
    @control_queue = control_queue
  end
  
  def new_connection_id
    UUID.timestamp_create.hexdigest
  end
  
  def spawn_connection_threads(connection)
    D "sending create connection command for #{connection[:id]}"    
    @control_queue << CreateConnectionCommand.new(connection[:id]).
                      to_encoded_str
    super
  end

  def inbound_data(connection, data)
    @control_queue << SendDataCommand.new(connection[:id], data).to_encoded_str
  end
  
  def closed_connection(connection)
    D "sending close connection command for #{connection[:id]}"
    
    @control_queue << CloseConnectionCommand.new(connection[:id]).to_encoded_str
  end
end

class RTunnel::ControlServer < RTunnel::AbstractServer
  include RTunnel
  
  attr_accessor :ping_interval

  def initialize(address)
    super
    @connections_by_port = {}    
  end
  
  def new_connection(socket)
    conn = super
    conn[:in_queue] = RTunnel::ThreadedIOString.new
    conn
  end
  
  def incoming_connection(socket, socket_address)
    conn = super
    spawn_command_processor conn
  end
  
  def inbound_data(connection, data)
    connection[:in_queue] << data
  end
  
  def close_connection(connection_id)
    conn = super
    return unless conn
    conn[:in_queue].writer_close
    if listen_server = conn[:listen_serv]
      listen_server.close
    end
    if port = conn[:port]
      @connections_lock.synchronize do
        if @connections_by_port[port] == conn
          @connections_by_port.delete port
        end
      end
    end
  end
    
  # Spawn a thread processing commands from the connection's inbound queue.
  # The thread is stopped by closing the queue via writer_close.
  def spawn_command_processor(connection)
    D "processing commands from connection #{connection[:id]}"
    logged_thread do
      cmd_queue = connection[:in_queue]
      while command = Command.decode(cmd_queue)
        process_command connection, command
      end
    end
  end
  
  def process_command(connection, command)
    case command
    when RemoteListenCommand
      process_remote_listen(connection, command.address)
    when SendDataCommand
      process_send_data(connection, command.connection_id, command.data)
    when CloseConnectionCommand
      process_close_connection(connection, command.connection_id)
    else
      W "bad command received: #{command.inspect}"
    end
  end
  
  def process_remote_listen(connection, address)
    port = SocketFactory.port_from_address address
    
    listen_server = nil
    @connections_lock.synchronize do
      close_connection_at_port port, true
      
      listen_server = RemoteListenServer.new(address, connection[:queue])
      @connections_by_port[port] = listen_server
      connection[:listen_serv] = listen_server
      connection[:port] = port
    end
    listen_server.start
    D "listening for remote connections on #{address}"
  end
  
  def process_send_data(connection, tunnel_connection_id, data)    
    listen_server = connection[:listen_serv]
    if listen_server
      listen_server.enqueue_outbound_data tunnel_connection_id, data
    else
      W "send data before opening listen socket on connection #{tunnel_connection_id}"
    end
  end
  
  def process_close_connection(connection, tunnel_connection_id)
    listen_server = connection[:listen_serv]
    if listen_server
      D "closing remote connection: #{tunnel_connection_id}"
      listen_server.close_connection tunnel_connection_id
    else
      W "close connection before opening listening socket on connection #{tunnel_connection_id}"
    end
  end
  
  def close_connection_at_port(port, already_synchronized = false)
    if already_synchronized
      if connection = @connections_by_port.delete(port)
        connection.stop
      end
    else
      @connections_lock.synchronize { close_connection_at_port port, true }
    end
  end

  def start
    super
    @thread_killer = [false]
    spawn_ping_thread
  end

  def stop
    super
  end

  # Spawns a thread that pings every connection.
  def spawn_ping_thread
    logged_thread do
      thread_killer = @thread_killer
      loop do
        break if thread_killer[0]
        sleep @ping_interval
        
        break if thread_killer[0]
        connections = @connections_lock.synchronize { @connections.values.dup }
        encoded_ping_command = PingCommand.new.to_encoded_str
        connections.each do |conn|
          conn[:queue].push encoded_ping_command
        end
      end
    end
  end
end


# The RTunnel server class, managing control and connection servers.
class RTunnel::Server
  def initialize(options = {})
    process_options options    
  end
  
  def start
    @control_server = RTunnel::ControlServer.new @control_address
    @control_server.ping_interval = @ping_interval

    @control_server.start
    self
  end
 
  def join
    @control_server.join
  end
 
  def stop
    @control_server.stop
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
