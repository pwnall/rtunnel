require 'rtunnel'
require 'test/unit'

class SocketFactoryTest < Test::Unit::TestCase
  SF = RTunnel::SocketFactory
  
  def setup
    
  end

  def teardown
    
  end
  
  def test_host_from_address
    assert_equal nil, SF.host_from_address(nil)
    assert_equal '127.0.0.1', SF.host_from_address('127.0.0.1')
    assert_equal '127.0.0.1', SF.host_from_address('127.0.0.1:1234')
    assert_equal 'fe80::1%lo0', SF.host_from_address('fe80::1%lo0')
    assert_equal 'fe80::1%lo0', SF.host_from_address('fe80::1%lo0:19020')
  end
  
  def test_port_from_address
    assert_equal nil, SF.port_from_address(nil)
    assert_equal nil, SF.port_from_address('127.0.0.1')
    assert_equal 1234, SF.port_from_address('127.0.0.1:1234')
    assert_equal nil, SF.port_from_address('fe80::1%lo0')
    assert_equal 19020, SF.port_from_address('fe80::1%lo0:19020')
  end
  
  def test_inbound
    assert SF.inbound?(:in_port => 1)
    assert SF.inbound?(:in_host => '1')
    assert SF.inbound?(:in_addr => '1')
    assert SF.inbound?(:inbound => true)
    assert !SF.inbound?(:out_port => 1)
    assert !SF.inbound?(:out_host => '1')
    assert !SF.inbound?(:out_addr => '1')
  end
end

