require 'rtunnel'

require 'resolv'
require 'test/unit'

class ServerTest < Test::Unit::TestCase
  def setup
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

    assert_equal RTunnel::PING_INTERVAL, server.extract_ping_interval(nil)
    assert_equal 29, server.extract_ping_interval(29)
    
    assert_equal nil, server.extract_authorized_keys(nil)
    keyset = server.extract_authorized_keys 'test_data/known_hosts'
    assert_equal RTunnel::Crypto::KeySet, keyset.class
    assert keyset.length != 0, 'No key read from the known_hosts file'
  end
end