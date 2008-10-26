require 'rubygems'
gem 'uuidtools', '>=1.0.2'
require 'uuidtools'

require 'core'
require 'cmds'

require 'gserver'

Socket.do_not_reverse_lookup = true

$debug = true

module RTunnel
  # listens for incoming connections to tunnel
  class RemoteListenServer < GServer
    CONNECTIONS = {}
    CONTROL_CONNECTION_MAPPING = {}

    def initialize(port, host, control_connection)
      super(port, host, 10)
      @control_connection = control_connection
      @maxConnections = 1024
    end

    def serve(sock)
      D "new incoming connection"

      conn_id = UUID.timestamp_create.hexdigest
      CONNECTIONS[conn_id] = sock
      CONTROL_CONNECTION_MAPPING[conn_id] = @control_connection
      begin
        ControlServer.new_tunnel(conn_id)

        sock.while_reading do |buf|
          begin
            ControlServer.send_data(conn_id, buf)
          rescue Exception
            D "error talking on control connection, dropping incoming connection: #{$!.inspect}"
            break
          end
        end
      rescue IOError
        raise  unless $!.message =~ /stream closed/i
      end

      ControlServer.close_tunnel(conn_id)

      CONNECTIONS.delete conn_id
      CONTROL_CONNECTION_MAPPING.delete conn_id

      D "sock closed"
    rescue
      p $!
      puts $!.backtrace.join("\n")
    end
  end

  class ControlServer < GServer
    @@control_connections = []
    @@remote_listen_servers = []

    @@m = Mutex.new

    attr_accessor :ping_interval

    def initialize(*args)
      super
      @maxConnections = 1024
    end

    class << self
      def new_tunnel(conn_id)
        D "sending create connection command: #{conn_id}"

        @@m.synchronize { control_connection_for(conn_id).write CreateConnectionCommand.new(conn_id) }
      end

      def send_data(conn_id, data)
        @@m.synchronize { control_connection_for(conn_id).write SendDataCommand.new(conn_id, data) }
      end

      def close_tunnel(conn_id)
        D "sending close connection command"

        @@m.synchronize { control_connection_for(conn_id).write CloseConnectionCommand.new(conn_id) }
      end

      private

      def control_connection_for(conn_id)
        RemoteListenServer::CONTROL_CONNECTION_MAPPING[conn_id]
      end
    end

    def starting
      start_pinging
    end

    def serve(sock)
      D "new control connection"
      @@control_connections << sock
      sock.sync = true

      cmd_queue = ""
      sock.while_reading(cmd_queue = '') do
        while Command.match(cmd_queue)
          case cmd = Command.parse(cmd_queue)
          when RemoteListenCommand
            @@m.synchronize do
              addr, port = cmd.address.split(/:/)
              if rls = @@remote_listen_servers.detect {|s| s.port == port.to_i }
                rls.stop
                @@remote_listen_servers.delete rls
              end
              (new_rls = RemoteListenServer.new(port, addr, sock)).start
              @@remote_listen_servers << new_rls
            end
            D "listening for remote connections on #{cmd.address}"
          when SendDataCommand
            conn = RemoteListenServer::CONNECTIONS[cmd.conn_id]
            begin
              conn.write(cmd.data)  if conn
            rescue Errno::EPIPE
              D "broken pipe on #{cmd.conn_id}"
            end
          when CloseConnectionCommand
            if connection = RemoteListenServer::CONNECTIONS[cmd.conn_id]
              D "closing remote connection: #{cmd.conn_id}"
              connection.close
            end
          else
            D "bad command received: #{cmd.inspect}"
          end
        end
      end
    rescue Errno::ECONNRESET
      D "client disconnected (conn reset)"
    rescue
      D $!.inspect
      D $@*"\n"
      raise
    ensure
      @@control_connections.delete sock
    end

    def stopping
      @ping_thread.kill
      @@remote_listen_server.stop
    end

    private

    def start_pinging
      @ping_thread = Thread.safe do
        loop do
          sleep @ping_interval

          @@m.synchronize do
            @@control_connections.each {|cc| cc.write PingCommand.new }
          end
        end
      end
    end
  end

  class Server
    def initialize(options = {})
      @control_address = options[:control_address]
      if ! @control_address
        @control_address = "0.0.0.0:#{DEFAULT_CONTROL_PORT}"  if ! @control_address
      elsif @control_address =~ /^\d+$/
        @control_address.insert 0, "0.0.0.0:"
      elsif @control_address !~ /:\d+$/
        @control_address << ":#{DEFAULT_CONTROL_PORT}"
      end
      @control_host = @control_address.split(/:/).first

      @ping_interval = options[:ping_interval] || 2.0
    end

    def start
      @control_server = ControlServer.new(*@control_address.split(/:/).reverse)
      @control_server.ping_interval = @ping_interval
      @control_server.audit = true

      @control_server.start
    end

    def join
      @control_server.join
    end

    def stop
      @control_server.shutdown
      ControlServer.stop(@control_server.port, @control_server.host)
    end
  end
end
