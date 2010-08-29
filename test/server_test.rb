require File.expand_path('../test_helper.rb', __FILE__)

class ServerTest < Test::Unit::TestCase
  def setup    
    super
    @server = RTunnel::Server.new(:control_address => 'localhost')
    @localhost_addr = Resolv.getaddress 'localhost'
  end
  
  def test_options
    server = RTunnel::Server
    assert_equal "18.241.3.100:#{RTunnel::DEFAULT_CONTROL_PORT}",
                 server.extract_control_address('18.241.3.100')                 
    assert_equal "18.241.3.100:9199",
                 server.extract_control_address('18.241.3.100:9199')
    assert_equal "#{@localhost_addr}:#{RTunnel::DEFAULT_CONTROL_PORT}",
                 server.extract_control_address('localhost')                 
    assert_equal "#{@localhost_addr}:9199",
                 server.extract_control_address('localhost:9199')
    assert_equal "0.0.0.0:9199",
                 server.extract_control_address('9199')

    assert_equal RTunnel::KEEP_ALIVE_INTERVAL,
                 server.extract_keep_alive_interval(nil)
    assert_equal 29, server.extract_keep_alive_interval(29)
    
    assert_equal 0, server.extract_lowest_listen_port(nil)
    assert_equal 29, server.extract_lowest_listen_port(29)
    assert_equal 65535, server.extract_highest_listen_port(nil)
    assert_equal 29, server.extract_highest_listen_port(29)
    
    assert_equal nil, server.extract_authorized_keys(nil)
    keyset = server.extract_authorized_keys 'test_data/known_hosts'
    assert_equal RTunnel::Crypto::KeySet, keyset.class
    assert keyset.length != 0, 'No key read from the known_hosts file'
  end
  
  def test_validate_remote_listen
    # remove Connection's new override, don't want event_machine here
    EventMachine::Connection.class_eval do
      class << self
        alias_method :backup_new, :new
        remove_method :new
      end
    end
    
    server = RTunnel::Server.new(:control_address => 'localhost',
                                 :lowest_listen_port => 91,
                                 :highest_listen_port => 105)
    connection = RTunnel::Server::ControlConnection.new server
        
    assert !connection.validate_remote_listen('localhost', 80)
    assert connection.validate_remote_listen('localhost', 91)
    assert connection.validate_remote_listen('localhost', 105)
    assert !connection.validate_remote_listen('localhost', 90)
    assert !connection.validate_remote_listen('localhost', 106)

    # re-instate Connection's new override
    EventMachine::Connection.class_eval do
      class << self
        alias_method :new, :backup_new
        remove_method :backup_new
      end
    end
  end
end
