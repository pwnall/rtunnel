require 'stringio'
require 'test/unit'

require 'rtunnel'
require 'test/command_stubs.rb'

class CommandsTest < Test::Unit::TestCase
  include CommandStubs
  
  def setup
    super
    @str = StringIO.new
  end
    
  CommandStubs.command_names.each do |cmd|
    define_method "test_#{cmd}_encode" do
      command = self.send "generate_#{cmd}"
      command.encode @str
      @str.rewind
      decoded_command = RTunnel::Command.decode @str
      self.send "verify_#{cmd}", decoded_command
      assert_equal "", @str.read, "Command #{cmd} did not consume its entire outpt"
    end
    
    define_method "test_#{cmd}_to_encoded_str" do
      command = self.send "generate_#{cmd}"
      command.encode @str
      @str.rewind
      assert_equal @str.read, command.to_encoded_str
    end    
  end
  
  def test_all_encodes
    sequence = CommandStubs.command_test_sequence
    sequence.each { |cmd| self.send("generate_#{cmd}").encode @str }
    @str.rewind
    sequence.each do |cmd|
      command = RTunnel::Command.decode(@str)
      self.send "verify_#{cmd}", command
    end
    assert_equal "", @str.read
  end
end
