# Contains generate_ and verify_ names for all RTunnel commands.
module CommandStubs
  @@test_id1 = "1029384756ALSKDJFH"
  @@test_id2 = "ALSKDJFH1029384756"
  @@test_address = "192.168.43.95"
  @@data = (0..255).to_a.pack('C*')
  @@ekey = (128...192).to_a.pack('C*') * 8
  @@pubfp = (0...128).to_a.pack('C*') * 5
  
  def generate_ping
    RTunnel::PingCommand.new
  end
  def verify_ping(cmd)
    assert_equal RTunnel::PingCommand, cmd.class
  end
  
  def generate_create
    RTunnel::CreateConnectionCommand.new @@test_id1
  end
  def verify_create(cmd)
    assert_equal RTunnel::CreateConnectionCommand, cmd.class
    assert_equal @@test_id1, cmd.connection_id
  end
  
  def generate_close
    RTunnel::CloseConnectionCommand.new @@test_id2
  end
  def verify_close(cmd)
    assert_equal RTunnel::CloseConnectionCommand, cmd.class
    assert_equal @@test_id2, cmd.connection_id
  end

  def generate_listen
    RTunnel::RemoteListenCommand.new @@test_address
  end
  def verify_listen(cmd)
    assert_equal RTunnel::RemoteListenCommand, cmd.class
    assert_equal @@test_address, cmd.address
  end

  def generate_send
    RTunnel::SendDataCommand.new @@test_id1, @@data
  end
  def verify_send(cmd)
    assert_equal RTunnel::SendDataCommand, cmd.class
    assert_equal @@test_id1, cmd.connection_id
    assert_equal @@data, cmd.data
  end
  
  def generate_set_sk
    RTunnel::SetSessionKeyCommand.new @@ekey
  end
  def verify_set_sk(cmd)
    assert_equal RTunnel::SetSessionKeyCommand, cmd.class
    assert_equal @@ekey, cmd.encrypted_keys
  end

  def generate_gen_sk
    RTunnel::GenerateSessionKeyCommand.new @@pubfp
  end
  def verify_gen_sk(cmd)
    assert_equal RTunnel::GenerateSessionKeyCommand, cmd.class
    assert_equal @@pubfp, cmd.public_key_fp
  end

  # An array with the names of all commands.
  # Use these names to obtain the names of the genrate_ and verify_ methods.
  def self.command_names
    [:ping, :create, :close, :listen, :send, :gen_sk, :set_sk]
  end

  # A sequence of command names useful for testing "real" connections.
  def self.command_test_sequence
    [:create, :ping, :gen_sk, :set_sk, :ping, :listen, :ping, :send, :send,
     :ping, :ping, :send, :close]
  end
end