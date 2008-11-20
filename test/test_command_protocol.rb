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
  C = RTunnel::Crypto
  
  def setup
    super
    @send_mock = EmSendCommandsMock.new
  end
  
  def teardown
    super
  end
  
  def commandset_test(names)
    @send_mock.command_hasher = @hasher if @hasher
    names.each do |name|
      command = self.send "generate_#{name}".to_sym
      @send_mock.send_command command
    end
    receive_mock = EmReceiveCommandsMock.new([@send_mock.string])
    receive_mock.command_hasher = C::Hasher.new(@hasher.key) if @hasher
    o_commands = receive_mock.replay.commands
    self.assert_equal names.length, o_commands.length
    names.each_index do |i|
      self.send "verify_#{names[i]}", o_commands[i]
    end
  end
  
  CommandStubs.command_names.each do |name|
    define_method "test_#{name}".to_sym do
      commandset_test [name]
    end

    define_method "test_signed_#{name}".to_sym do
      @hasher = C::Hasher.new
      commandset_test [name]
    end
    
    define_method "test_signed_#{name}_has_signature".to_sym do
      sig_send_mock = EmSendCommandsMock.new
      sig_send_mock.command_hasher = C::Hasher.new
      outputs = [@send_mock, sig_send_mock].map do |mock|
        mock.send_command self.send("generate_#{name}".to_sym)
        mock.string
      end
      assert outputs.first.length < outputs.last.length,
             "No signature generated"
    end
    
    define_method "test_signed_#{name}_enforces_signature".to_sym do
      @send_mock.command_hasher = hasher = C::Hasher.new
      @send_mock.send_command self.send("generate_#{name}".to_sym)      
      signed_str = @send_mock.string
      
      0.upto(signed_str.length - 1) do |i|
        bad_str = signed_str.dup
        bad_str[i] ^= 0x01
        recv_mock = EmReceiveCommandsMock.new([bad_str])
        recv_mock.command_hasher = C::Hasher.new hasher.key
        assert_equal [], recv_mock.replay.commands
      end      
    end
  end
end