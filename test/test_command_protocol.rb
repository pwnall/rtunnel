require 'test/unit'

require 'rtunnel'
require 'test/command_stubs.rb'
require 'test/protocol_mocks.rb'

class CommandProtocolTest < Test::Unit::TestCase
  include CommandStubs
  
  def setup
    super
    @send_mock = EmSendMock.new
  end
  
  def teardown
    super
  end
  
  def commandset_test(commands)
    @send_mock
  end
  
  def test_something
    
  end
end