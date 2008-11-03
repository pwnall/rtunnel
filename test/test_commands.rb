require 'rtunnel'
require 'test/unit'

class CommandsTest < Test::Unit::TestCase
  def setup
    @str = RTunnel::IOString.new
    @test_id1 = "1029384756ALSKDJFH"
    @test_id2 = "ALSKDJFH1029384756"
    @test_address = "192.168.43.95"
    @data = (0..255).to_a.pack('C*')
  end
  
  def write_ping
    cmd = RTunnel::PingCommand.new
    cmd.encode @str
  end
  def assert_ping
    cmd = RTunnel::Command.decode @str
    assert_equal RTunnel::PingCommand, cmd.class
  end
  
  def write_create
    cmd = RTunnel::CreateConnectionCommand.new @test_id1
    cmd.encode @str
  end
  def assert_create
    cmd = RTunnel::Command.decode @str
    assert_equal RTunnel::CreateConnectionCommand, cmd.class
    assert_equal @test_id1, cmd.connection_id
  end
  
  def write_close
    cmd = RTunnel::CloseConnectionCommand.new @test_id2
    cmd.encode @str
  end
  def assert_close
    cmd = RTunnel::Command.decode @str
    assert_equal RTunnel::CloseConnectionCommand, cmd.class
    assert_equal @test_id2, cmd.connection_id
  end

  def write_listen
    cmd = RTunnel::RemoteListenCommand.new @test_address
    cmd.encode @str
  end
  def assert_listen
    cmd = RTunnel::Command.decode @str
    assert_equal RTunnel::RemoteListenCommand, cmd.class
    assert_equal @test_address, cmd.address
  end

  def write_send
    cmd = RTunnel::SendDataCommand.new @test_id1, @data
    cmd.encode @str
  end
  def assert_send
    cmd = RTunnel::Command.decode @str
    assert_equal RTunnel::SendDataCommand, cmd.class
    assert_equal @test_id1, cmd.connection_id
    assert_equal @data, cmd.data
  end

  [:ping, :create, :close, :listen, :send].each do |cmd|
    define_method "test_#{cmd}" do
      self.send "write_#{cmd}"
      self.send "assert_#{cmd}"
      assert_equal "", @str.read, "Command #{cmd} did not consume its entire outpt"
    end
  end
  
  def test_all
    sequence = [:create, :ping, :listen, :ping, :send, :send, :ping, :ping, :send, :close]
    sequence.each { |cmd| self.send "write_#{cmd}".to_sym }    
    sequence.each { |cmd| self.send "assert_#{cmd}".to_sym }
    assert_equal "", @str.read
  end
end
