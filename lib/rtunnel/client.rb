require 'resolv'
require 'thread'
require 'timeout'

require 'rubygems'

class RTunnel::Client
  include RTunnel
  include RTunnel::Logging
  include RTunnel::SocketFactory
  
  attr_reader :control_address, :control_host
  attr_reader :remote_listen_address, :tunnel_to_address
  attr_reader :ping_timeout
  attr_reader :logger
  
  def initialize(options = {})
    process_options options
    init_log options
    @connections = {}
    @connections_lock = Mutex.new
    @control_sock_lock = Mutex.new
  end
  
  def start
    @thread_killer = [false]

    spawn_ping_thread

    # RTunnel::LeakTracker.start
    
    spawn_main_thread

    self
  end
  
  def join
    @main_thread.join
  end

  def stop
    @thread_killer[0] = true
    disconnect_control_sock
  end
  
  
  ## option processing
  
  # Resolve the given address to an IP.
  # The address can have the following formats: host; host:port; ip; ip:port;
  def self.resolve_address(address, timeout_sec = 5)
    host, rest = address.split(':', 2)
    ip = timeout(timeout_sec) { Resolv.getaddress(host) }
    return rest ? "#{ip}:#{rest}" : ip
  rescue Exception
    raise AbortProgramException, "Error resolving #{host}" 
  end
  
  def self.extract_control_address(address)
    unless address =~ /:\d+$/
      address = "#{address}:#{RTunnel::DEFAULT_CONTROL_PORT}"
    end
    resolve_address address
  end
  
  def self.extract_remote_listen_address(address)
    address = "0.0.0.0:#{address}" if address =~ /^\d+$/    
    resolve_address address
  end
  
  def self.extract_tunnel_to_address(address)
    address = "localhost:#{address}" if address =~ /^\d+$/    
    resolve_address address
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
  
  # Perform one command coming from the control connection. 
  def process_command(command)
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
    connection_id = command.connection_id
    connection_data = register_new_connection connection_id
    
    logged_thread do
      begin
        connection_data[:sock] = TCPSocket.new(*@tunnel_to_address.split(/:/))
      rescue Exception
        I "error connecting to local port for #{connection_id}"
        write_to_control_sock CloseConnectionCommand.new(connection_id)
      end
      spawn_connection_writer connection_data
      spawn_connection_reader connection_data
    end
  end
  
  # CloseConnectionCommand handler
  def process_close_connection(connection_id)
    I "closing connection #{connection_id}"
    logged_thread do
      close_connection connection_id
    end
  end
  
  # SendData handler
  def process_send_data(connection_id, data)
    @connection_lock.synchronize do
      if connection_data = @connections[connection_id]
        connection_data[:queue] << data
      else
        W "Received data for non existant connection!"  
      end
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
  
  # Disconnect the control socket.
  def disconnect_control_sock
    @control_sock.close rescue nil
  end
  
  # Write a command to the control socket.
  def write_to_control_sock(command)
    @control_sock_lock.synchronize { @control_sock.write command.to_encoded_str}
  end
  
  # Send a ListenCommand to the control address.
  def send_listen_command
    write_to_control_sock RemoteListenCommand.new(@remote_listen_address)
  end
  
  
  ## connection management
  
  # Spawn a thread that reads packets from the control socket and transfers
  # them to a ThreadedStringBuffer.
  # The thread is terminated by closing the control socket.
  def spawn_control_sock_reader(io)
    logged_thread do
      thread_killer = @thread_killer
      begin
        loop do
          data = @control_sock.readpartial 16384
          break unless data
          io << data
        end
      rescue
        W "control sock read error: #{$!.inspect}" unless thread_killer[0]
      ensure
        io.writer_close
      end
    end
  end
  
  # Spawn a thread that writes data from a connection's outbound queue to the
  # connection's socket.
  # The thread is terminated by pushing a nil into the connection's queue.
  def spawn_connection_writer(connection_data)
    queue = connection_data[:queue]
    logged_thread do
      while data = queue.pop
        connection.write data
      end
    end
  end
  
  # Spawn a thread that reads data from 
  def spawn_connection_reader(connection_data)
    sock = connection_data[:sock]
    connection_id = connection_data[:id]
    logged_thread do
      begin
        while data = sock.readpartial(16834)
          write_to_control_sock SendDataCommand.new(connection_id, data)
        end
      rescue Exception
        D "to tunnel closed, closing from tunnel"      
        close_connection connection_id
      end
    end
  end
  
  def close_connection(connection_id)
    return unless connection_data = deregister_connection(connection_id)
    connection_data[:queue] << nil    
    write_to_control_sock CloseConnectionCommand.new(connection_data[:connection_id])
    connection_data[:sock].close
  end

  # Close all the port forwarding connections (not the control connection.)
  def close_all_connections
    connection_ids = @connections_lock.synchronize { @connections.keys }
    connection_ids.each { |connection_id| close_connection connection_id }
  end

  # Register a new port forwarding connection. This method is thread-safe.
  # Registering a connection keeps track of its socket and outbound queue.
  def register_connection(connection_id, connection_data)
    connection_data = { :id => connection_id, :queue => Queue.new, :sock => nil }
    @connection_lock.synchronize do
      # TODO(costan): check that the connection_id isn't already in use
      @connections[connection_id] = connection_data
    end
    connection_data
  end
  
  # De-register a port forwarding connection. This method is thread-safe.
  def deregister_connection(connection_id)
    @connections_lock.synchronize { @connections.delete connection_id }
  end  
  
  
  ## Pinging for the control connection

  def ping_timeout?
    return false unless @ping_lock
    return @ping_lock.synchronize { (Time.now - @last_ping) > @ping_timeout }
  end
  
  # Acknowledge a ping received from the control connection.
  def process_ping
    @ping_lock and @ping_lock.synchronize { @last_ping = Time.now }
  end

  # Spawn a thread that closes the control connection on ping timeouts.
  def spawn_ping_thread
    @last_ping = Time.now
    logged_thread do
      thread_killer = @thread_killer
      while true
        break if thread_killer[0]

        if ping_timeout?
          W "control connection timeout"
          @control_sock.close rescue nil
        end

        break if thread_killer[0]
        sleep 1
      end
    end    
  end

  # Disables processing of ping timeouts. The control connection will not be
  # closed by the ping thread.
  def disable_ping_timeouts
    @ping_lock = false
  end

  # After this is called, the ping thread will close the control connection upon
  # ping timeouts.
  def enable_ping_timeouts
    @last_ping = Time.now
    @ping_lock = Mutex.new
  end
end
