require 'stringio'

class RTunnel::Command  
  # Associates command codes with the classes implementing them.
  class Registry
    def initialize
      @classes = {}
      @codes = {}
    end
  
    def register(klass, command_code)
      if @codes.has_key? command_code
        raise "Command code #{command_code} already used for #{@codes[command_code].name}"
      end
      
      @codes[klass] = command_code
      @classes[command_code] = klass
    end
    
    def class_for(command_code)
      @classes[command_code]
    end
    
    def code_for(klass)
      @codes[klass]
    end
    
    def codes_and_classes
      ret_val = []
      @codes.each { |klass, code| ret_val << [code, klass.name] }
      ret_val.sort!
    end
  end
  
  @@registry = Registry.new
  def self.registry
    @@registry
  end
  
  # subclasses must call this to register and declare their command code
  def self.command_code(code)
    registry.register self, code
  end

  # subclasses should override this (and add to the result)
  # to provide a debug string 
  def to_s
    self.class.name
  end
  
  # subclasses should override this and call super
  # before performing their own initialization
  def initialize_from_io(io)
    return self
  end

  # Encode this command to a IO / IOString.
  def encode(io)
    io.write RTunnel::Command.registry.code_for(self.class)
  end
  
  # Produce a string with an encoding of this command.
  def to_encoded_str
    string_io = StringIO.new
    self.encode string_io
    string_io.string
  end

  # Decode a Command instance from a IO / IOString.
  def self.decode(io)
    return nil unless code = io.getc
    klass = registry.class_for code.chr
    return nil unless klass

    command = klass.new
    command.initialize_from_io io
  end

  # Printable string containing all the codes and their classes.
  def self.printable_codes
    printable = ''
    registry.codes_and_classes.each do |code_and_class|
      printable << "#{code_and_class.first}: #{code_and_class.last}\n"
    end
    return printable
  end
end

class RTunnel::ConnectionCommand < RTunnel::Command
  attr_reader :connection_id

  def initialize(connection_id = nil)
    super()
    @connection_id = connection_id
  end
  
  def to_s
    super + "/id=#{connection_id}"
  end
  
  def initialize_from_io(io)
    super
    @connection_id = io.read_varstring
    self
  end
  
  def encode(io)
    super
    io.write_varstring @connection_id
  end
end

class RTunnel::CreateConnectionCommand < RTunnel::ConnectionCommand
  command_code 'C'
end

class RTunnel::CloseConnectionCommand < RTunnel::ConnectionCommand
  command_code 'X'
end

class RTunnel::SendDataCommand < RTunnel::ConnectionCommand
  command_code 'D'
  
  attr_reader :data

  def initialize(connection_id = nil, data = nil)
    super(connection_id)
    @data = data
  end
  
  def initialize_from_io(io)
    super
    @data = io.read_varstring
    self    
  end

  def to_s
    super + "/data=#{data}"
  end
  
  def encode(io)
    super
    io.write_varstring @data
  end
end

class RTunnel::RemoteListenCommand < RTunnel::Command
  command_code 'L'

  attr_reader :address

  def initialize(address = nil)
    super()
    @address = address
  end

  def to_s
    super + "/address=#{address}"
  end

  def initialize_from_io(io)
    super
    @address = io.read_varstring
    self    
  end
  
  def encode(io)
    super
    io.write_varstring address
  end
end

class RTunnel::PingCommand < RTunnel::Command
  command_code 'P'
  
  def initialize_from_io(io)
    super
  end
end

class RTunnel::GenerateSessionKeyCommand < RTunnel::Command
  command_code 'S'
  
  attr_reader :public_key_fp
  
  def initialize(public_key_fp = nil)
    super()
    @public_key_fp = public_key_fp
  end
  
  def to_s
    super + "/pubkey_fp=#{@public_key_fp.inspect}"
  end
  
  def initialize_from_io(io)
    super
    @public_key_fp = io.read_varstring
    self    
  end
  
  def encode(io)
    super
    io.write_varstring @public_key_fp
  end
end

class RTunnel::SetSessionKeyCommand < RTunnel::Command
  command_code 'K'
  
  attr_reader :encrypted_keys

  def initialize(encrypted_keys = nil)
    super()
    @encrypted_keys = encrypted_keys
  end
  
  def to_s
    super + "/enc_keys=#{@encrypted_key.inspect}"
  end
  
  def initialize_from_io(io)
    super
    @encrypted_keys = io.read_varstring
    self    
  end
  
  def encode(io)
    super
    io.write_varstring @encrypted_keys
  end
end

# TODO(not_me): this file (and its tests) cry for a DSL