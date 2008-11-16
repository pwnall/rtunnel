require 'rtunnel'

require 'test/unit'

require 'test/command_stubs.rb'
require 'test/protocol_mocks.rb'

# Send mock for commands.
class EmSendCommandsMock < EmSendMock
  include RTunnel::CommandProtocol
end

# Receive mock for commands.
class EmReceiveCommandsMock < EmReceiveMock
  include RTunnel::CommandProtocol
  object_name :command
end

class CommandProtocolTest < Test::Unit::TestCase
  include CommandStubs
  
  def setup
    super
    @send_mock = EmSendCommandsMock.new
  end
  
  def teardown
    super
  end
  
  def commandset_test(names)
    names.each do |name|
      command = self.send "generate_#{name}".to_sym
      @send_mock.send_command command
    end
    o_commands = EmReceiveCommandsMock.new([@send_mock.string]).replay.commands
    self.assert_equal names.length, o_commands.length
    names.each_index do |i|
      self.send "verify_#{names[i]}", o_commands[i]
    end
  end
  
  CommandStubs.command_names.each do |name|
    define_method "test_#{name}".to_sym do
      commandset_test [name]
    end
  end
end