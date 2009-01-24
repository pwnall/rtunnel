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
    @secure_connection_time = 0.5
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
  
  def tunnel_test(connection_time = nil)
    @stop_proc = proc do
      @tunnel_client.stop
      @tunnel_server.stop
      @stop_proc = nil
    end

    EventMachine::run do
      @tunnel_server.start
      @tunnel_client.start

      if connection_time
        EventMachine.add_timer(connection_time) { yield }
      else
        EventMachine.next_tick { yield }
      end
    end
  end
  
  def test_client_driven_tunnel
    tunnel_test do
      @tunnel_server.on_remote_listen do
        EventMachine::start_server @local_host, @tunnel_port,
            ScenarioConnection, self, [[:recv, 'Hello'], [:send, 'World'],
                                       [:unbind], [:stop, @stop_proc]]

        EventMachine::connect @local_host, @listen_port,
            ScenarioConnection, self, [[:send, 'Hello'], [:recv, 'World'],
                                       [:close]]
      end
    end
  end
  
  def test_server_driven_tunnel
    tunnel_test do
      @tunnel_server.on_remote_listen do
        EventMachine::start_server @local_host, @tunnel_port,
            ScenarioConnection, self, [[:send, 'Hello'], [:recv, 'World'],
                                       [:close]]

        EventMachine::connect @local_host, @listen_port,
            ScenarioConnection, self, [[:recv, 'Hello'], [:send, 'World'],
                                       [:unbind], [:stop]]
      end  
    end    
  end
  
  def test_two_tunnels
    start_second = lambda do
      @tunnel_client.stop
      @tunnel_client.start
      @tunnel_server.on_remote_listen do
        EventMachine::connect @local_host, @listen_port,
            ScenarioConnection, self, [[:send, 'Hello'], [:recv, 'World'],
                                       [:unbind], [:stop, @stop_proc]]
      end
    end
    
    tunnel_test do
      @tunnel_server.on_remote_listen do
        EventMachine::start_server @local_host, @tunnel_port,
            ScenarioConnection, self, [[:recv, 'Hello'], [:send, 'World'],
                  [:close], [:recv, 'Hello'], [:send, 'World'], [:close]]

        EventMachine::connect @local_host, @listen_port,
            ScenarioConnection, self, [[:send, 'Hello'], [:recv, 'World'],
                                       [:proc, start_second], [:unbind]]
      end
    end
  end
  
  def test_secure_tunnel
    @tunnel_server = new_server :authorized_keys => @hosts_file
    @tunnel_client = new_client :private_key => @key_file
    tunnel_test do
      @tunnel_server.on_remote_listen do
        EventMachine::start_server @local_host, @tunnel_port,
            ScenarioConnection, self, [[:recv, 'Hello'], [:send, 'World'],
                                       [:unbind], [:stop, @stop_proc]]

        EventMachine::connect @local_host, @listen_port,
            ScenarioConnection, self, [[:send, 'Hello'], [:recv, 'World'],
                                       [:close]]
      end
    end
  end

  def test_secure_async_tunnel
    @tunnel_server = new_server :authorized_keys => @hosts_file
    @tunnel_client = new_client :private_key => @key_file
    tunnel_test do
      @tunnel_server.on_remote_listen do
        EventMachine::start_server @local_host, @tunnel_port,
            ScenarioConnection, self, [[:send, 'World'], [:recv, 'Hello'],
                                       [:unbind], [:stop, @stop_proc]]

        EventMachine::connect @local_host, @listen_port,
            ScenarioConnection, self, [[:send, 'Hello'], [:recv, 'World'],
                                       [:close]]
      end
    end
  end
  
  def test_bad_listen_address
    @tunnel_server = new_server
    @tunnel_client = new_client :remote_listen_address =>
                                "18.70.0.160:#{@listen_port}"
                                
    tunnel_test do
      EventMachine::start_server @local_host, @tunnel_port,
          ScenarioConnection, self, []
                                     
      EventMachine::connect @local_host, @listen_port,
          ScenarioConnection, self, [[:unbind], [:stop, @stop_proc]]
    end
  end

  # TODO: fix this
  def test_secure_server_rejects_unsecure_client
    @tunnel_server = new_server :authorized_keys => @hosts_file
    tunnel_test(@secure_connection_time) do
      EventMachine::start_server @local_host, @tunnel_port,
          ScenarioConnection, self, []
                                     
      EventMachine::connect @local_host, @listen_port,
          ScenarioConnection, self, [[:unbind], [:stop, @stop_proc]]
    end
  end

  # hrmf... this is testing security and its not 100% reliable... but I can't think of a better way
  def test_secure_server_rejects_unauthorized_key
    @tunnel_server = new_server :authorized_keys => @hosts_file
    @tunnel_client = new_client :private_key => 'test_data/random_rsa_key'
    tunnel_test(@secure_connection_time) do
      EventMachine::start_server @local_host, @tunnel_port,
          ScenarioConnection, self, []

      EventMachine::connect @local_host, @listen_port,
          ScenarioConnection, self, [[:unbind], [:stop, @stop_proc]]
    end
  end
end