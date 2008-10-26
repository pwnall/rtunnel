require 'core'
require 'cmds'
require 'leak'

require 'gserver'
require 'timeout'

module RTunnel
  class Client
    CONNECTIONS = {}

    def initialize(options = {})
      @control_address = options[:control_address]
      @control_address << ":#{DEFAULT_CONTROL_PORT}"  if @control_address !~ /:\d+$/
      @control_host = @control_address.split(/:/).first

      @remote_listen_address = options[:remote_listen_address]
      @remote_listen_address.insert 0, "0.0.0.0:"  if @remote_listen_address =~ /^\d+$/

      @tunnel_to_address = options[:tunnel_to_address]
      @tunnel_to_address.insert 0, "localhost:"  if @tunnel_to_address =~ /^\d+$/

      [@control_address, @remote_listen_address, @tunnel_to_address].each do |addr|
        addr.replace_with_ip!
      end

      @ping_timeout = options[:ping_timeout] || PING_TIMEOUT
    end

    def start
      @threads = []

      @last_ping = Time.now

      @threads << Thread.safe do
        loop do
          if @check_ping and (Time.now - @last_ping) > @ping_timeout
            D "control connection timeout"
            @control_sock.close  rescue nil
          end

          sleep 1
        end
      end

      # Memory leak testing
      LeakTracker.start

      @main_thread = Thread.safe do
        loop do
          stop_ping_check
          D "connecting to control address (#{@control_address})"
          @control_sock = begin
            timeout(5) { TCPSocket.new(*@control_address.split(/:/)) }
          rescue Exception
            D "fail"
            sleep 1
            next
          end

          start_ping_check

          write_to_control_sock RemoteListenCommand.new(@remote_listen_address)

          cmd_queue = ""
          while data = (@control_sock.readpartial(16384)  rescue (D "control sock read error: #{$!.inspect}"; nil))
            cmd_queue << data
            while Command.match(cmd_queue)
              case command = Command.parse(cmd_queue)
              when PingCommand
                @last_ping = Time.now
              when CreateConnectionCommand
                begin
                  # TODO: this currently blocks, but if we put it in thread, a SendDataCommand may try to get run for this connection before the connection exists
                  CONNECTIONS[command.conn_id] = TCPSocket.new(*@tunnel_to_address.split(/:/))

                  Thread.safe do
                    cmd = command
                    conn = CONNECTIONS[cmd.conn_id]

                    begin
                      while localdata = conn.readpartial(16834)
                        write_to_control_sock SendDataCommand.new(cmd.conn_id, localdata)
                      end
                    rescue Exception
                      begin
                        D "to tunnel closed, closing from tunnel"
                        conn.close
                        CONNECTIONS.delete cmd.conn_id
                        write_to_control_sock CloseConnectionCommand.new(cmd.conn_id)
                      rescue
                        p $!
                        puts $!.backtrace.join("\n")
                      end
                    end
                  end                  
                rescue Exception
                  D "error connecting to local port"
                  write_to_control_sock CloseConnectionCommand.new(command.conn_id)
                end
              when CloseConnectionCommand
                D "closing connection #{command.conn_id}"
                if connection = CONNECTIONS[command.conn_id]
                  # TODO: how the hell do u catch a .close error?
                  connection.close_read
                  #connection.close  unless connection.closed?
                  CONNECTIONS.delete(command.conn_id)
                end
              when SendDataCommand
                if connection = CONNECTIONS[command.conn_id]
                  connection.write(command.data)
                else
                  puts "WARNING: received data for non existant connection!"
                end
              end
            end
          end
        end
      end

      @threads << @main_thread
    end

    def join
      @main_thread.join
    end

    def stop
      @threads.each { |t| t.kill! rescue nil}
      @control_sock.close  rescue nil
    end

    private

    def write_to_control_sock(data)
      (@control_sock_mutex ||= Mutex.new).synchronize do
        @control_sock.write data
      end
    end

    def start_ping_check
      @last_ping = Time.now
      @check_ping = true
    end

    def stop_ping_check
      @check_ping = false
    end
  end
end
