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
    @listen_port = 21335
    @tunnel_port = 21336
    @control_port = 21337
    @key_file = 'test_data/ssh_host_rsa_key'
    @hosts_file = 'test_data/known_hosts'
    
    @tunnel_server = new_server
    @tunnel_client = new_client
  end
  
  def new_server(extra_options = {})
    RTunnel::Server.new({
        :control_address => "#{@local_host}:#{@control_port}",
        :log_level => @log_level
        }.merge(extra_options))
  end
  
  def new_client(extra_options = {})
    RTunnel::Client.new({
            :control_address => "#{@local_host}:#{@control_port}",
            :remote_listen_address => "#{@local_host}:#{@listen_port}",
            :tunnel_to_address => "#{@local_host}:#{@tunnel_port}",
            :log_level => @log_level
            }.merge(extra_options))
  end
  
  def tunnel_test
    @stop_proc = proc do
      @tunnel_client.stop
      @tunnel_server.stop
      @stop_proc = nil
    end
    
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
                                     [:unbind], [:stop, @stop_proc]]
                                     
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
                                         [:unbind], [:stop, @stop_proc]]
        end
      end      
    end
    
    tunnel_test do      
      EventMachine::start_server @local_host, @tunnel_port,
          ScenarioConnection, self, [[:recv, 'Hello'], [:send, 'World'],
                                     [:close]]
                                     
      EventMachine::add_timer(@connection_time) do
        print "Starting client\n"
        EventMachine::connect @local_host, @listen_port,
            ScenarioConnection, self, [[:send, 'Hello'], [:recv, 'World'],
                                       [:proc, start_second], [:unbind]]
      end
    end
  end
  
  def test_secure_tunnel
    @tunnel_server = new_server :authorized_keys_file => @hosts_file
    @tunnel_client = new_client :private_key_file => @key_file
    tunnel_test do      
      EventMachine::start_server @local_host, @tunnel_port,
          ScenarioConnection, self, [[:recv, 'Hello'], [:send, 'World'],
                                     [:unbind], [:stop, @stop_proc]]
                                     
      EventMachine::add_timer(@connection_time) do
        print "Starting client\n"
        EventMachine::connect @local_host, @listen_port,
            ScenarioConnection, self, [[:send, 'Hello'], [:recv, 'World'],
                                       [:close]]
      end
    end
  end
end