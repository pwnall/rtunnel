require 'rtunnel'

require 'test/unit'

require 'rubygems'
require 'eventmachine'

require 'test/scenario_connection.rb'

# Integration tests ensuring that we can start a tunnel.
class TunnelTest < Test::Unit::TestCase
  def setup
    super
    
    @connection_time = 0.001
    @log_level = 'debug'
    @local_host = '127.0.0.1'
    @listen_port = 31335
    @tunnel_port = 31336
    @control_port = 31337
    
    @tunnel_server = RTunnel::Server.new(
        :control_address => "#{@local_host}:#{@control_port}",
        :log_level => @log_level)
    @tunnel_client = RTunnel::Client.new(
        :control_address => "#{@local_host}:#{@control_port}",
        :remote_listen_address => "#{@local_host}:#{@listen_port}",
        :tunnel_to_address => "#{@local_host}:#{@tunnel_port}",
        :log_level => @log_level)
  end
  
  def tunnel_test
    EventMachine::run do
      @tunnel_server.start
      @tunnel_client.start
      
      EventMachine::add_timer(@connection_time) { yield }
    end
  end
  
  def test_client_driven_tunnel
    tunnel_test do      
      EventMachine::start_server @local_host, @tunnel_port,
          ScenarioConnection, self, [[:recv, 'Hello'], [:send, 'World'],
                                     [:unbind], [:stop]]
                                     
      EventMachine::add_timer(@connection_time) do
        print "Starting client\n"
        EventMachine::connect @local_host, @listen_port,
            ScenarioConnection, self, [[:send, 'Hello'], [:recv, 'World'],
                                       [:close]]
      end
    end
  end
  
  def test_server_driven_tunnel
    tunnel_test do      
      EventMachine::start_server @local_host, @tunnel_port,
          ScenarioConnection, self, [[:send, 'Hello'], [:recv, 'World'],
                                     [:close]]
                                     
      EventMachine::add_timer(@connection_time) do
        print "Starting client\n"
        EventMachine::connect @local_host, @listen_port,
            ScenarioConnection, self, [[:recv, 'Hello'], [:send, 'World'],
                                       [:unbind], [:stop]]
      end
    end    
  end
  
  def test_two_tunnels
    start_second = proc do
      print "In proc\n"
      EventMachine::add_timer(@connection_time) do
        @tunnel_client.stop
        @tunnel_client.start
        EventMachine::add_timer(@connection_time) do
          EventMachine::connect @local_host, @listen_port,
              ScenarioConnection, self, [[:send, 'Hello'], [:recv, 'World'],
                                         [:close], [:stop]]
        end
      end      
    end
    
    tunnel_test do      
      EventMachine::start_server @local_host, @tunnel_port,
          ScenarioConnection, self, [[:recv, 'Hello'], [:send, 'World'],
                                     [:unbind]]
                                     
      EventMachine::add_timer(@connection_time) do
        print "Starting client\n"
        EventMachine::connect @local_host, @listen_port,
            ScenarioConnection, self, [[:send, 'Hello'], [:recv, 'World'],
                                       [:proc, start_second], [:close]]
      end
    end
  end
end