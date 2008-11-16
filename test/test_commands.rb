require 'rtunnel'
require 'test/unit'

class CommandsTest < Test::Unit::TestCase
  def setup
    @str = StringIO.new
    @test_id1 = "1029384756ALSKDJFH"
    @test_id2 = "ALSKDJFH1029384756"
    @test_address = "192.168.43.95"
    @data = (0..255).to_a.pack('C*')
  end
  
  def generate_ping
    RTunnel::PingCommand.new
  end
  def verify_ping
    cmd = RTunnel::Command.decode @str
    assert_equal RTunnel::PingCommand, cmd.class
  end
  
  def generate_create
    RTunnel::CreateConnectionCommand.new @test_id1
  end
  def verify_create
    cmd = RTunnel::Command.decode @str
    assert_equal RTunnel::CreateConnectionCommand, cmd.class
    assert_equal @test_id1, cmd.connection_id
  end
  
  def generate_close
    RTunnel::CloseConnectionCommand.new @test_id2
  end
  def verify_close
    cmd = RTunnel::Command.decode @str
    assert_equal RTunnel::CloseConnectionCommand, cmd.class
    assert_equal @test_id2, cmd.connection_id
  end

  def generate_listen
    RTunnel::RemoteListenCommand.new @test_address
  end
  def verify_listen
    cmd = RTunnel::Command.decode @str
    assert_equal RTunnel::RemoteListenCommand, cmd.class
    assert_equal @test_address, cmd.address
  end

  def generate_send
    RTunnel::SendDataCommand.new @test_id1, @data
  end
  def verify_send
    cmd = RTunnel::Command.decode @str
    assert_equal RTunnel::SendDataCommand, cmd.class
    assert_equal @test_id1, cmd.connection_id
    assert_equal @data, cmd.data
  end

  [:ping, :create, :close, :listen, :send].each do |cmd|
    define_method "test_#{cmd}_encode" do
      command = self.send "generate_#{cmd}"
      command.encode @str
      @str.rewind
      self.send "verify_#{cmd}"
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
    sequence = [:create, :ping, :listen, :ping, :send, :send, :ping, :ping, :send, :close]
    sequence.each { |cmd| self.send("generate_#{cmd}").encode @str }
    @str.rewind
    sequence.each { |cmd| self.send "verify_#{cmd}" }
    assert_equal "", @str.read
  end
end
