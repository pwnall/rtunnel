# Mocks the sending end of an EventMachine connection.
# The sent data is concatenated in a string available by calling #string.
class EmSendMock  
  attr_reader :string
  
  def initialize
    @string = ''
  end
  
  def send_data(data)
    @string << data
  end
end

# Mocks the receiving end of an EventMachine connection.
# The data to be received is passed as an array of strings to the constructor.
# Calling #replay mocks receiving the data.
class EmReceiveMock
  attr_accessor :strings
  attr_accessor :objects
  
  def initialize(strings = [''])
    @strings = strings
    @objects = []
  end
  
  def replay
    @strings.each { |str| receive_data str }
    self
  end

  def receive_object(object)
    @objects << object
  end
  
  # Declares the name of the object to be received. For instance, a frame
  # protocol would use :frame for name. This generates a receive_frame method,
  # and a frames accessor.
  def self.object_name(name)
    alias_method "receive_#{name}".to_sym, :receive_object
    alias_method "#{name}s".to_sym, :objects
  end
end
