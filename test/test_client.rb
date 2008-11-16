require 'rtunnel'

require 'resolv'
require 'test/unit'

class ClientTest < Test::Unit::TestCase
  def setup
    @client = RTunnel::Client.new(:control_address => 'localhost',
                                  :remote_listen_address => '9199',
                                  :tunnel_to_address => '4444')
    @localhost_addr = Resolv.getaddress 'localhost'
  end
  
  def test_options
    client = RTunnel::Client
    assert_equal "18.241.3.100:#{RTunnel::DEFAULT_CONTROL_PORT}",
                 client.extract_control_address('18.241.3.100')                 
    assert_equal "18.241.3.100:9199",
                 client.extract_control_address('18.241.3.100:9199')
    assert_equal "#{@localhost_addr}:#{RTunnel::DEFAULT_CONTROL_PORT}",
                 client.extract_control_address('localhost')                 
    assert_equal "#{@localhost_addr}:9199",
                 client.extract_control_address('localhost:9199')

    assert_equal "0.0.0.0:9199",
                 client.extract_remote_listen_address('9199')                 
    assert_equal "18.241.3.100:9199",
                 client.extract_remote_listen_address('18.241.3.100:9199')                 
    assert_equal "#{@localhost_addr}:9199",
                 client.extract_remote_listen_address('localhost:9199')

    assert_equal "18.241.3.100:9199",
                 client.extract_tunnel_to_address('18.241.3.100:9199')                 
    assert_equal "#{@localhost_addr}:9199",
                 client.extract_tunnel_to_address('9199')
                 
    assert_equal RTunnel::PING_TIMEOUT, client.extract_ping_timeout(nil)
    assert_equal 29, client.extract_ping_timeout(29)
  end
end