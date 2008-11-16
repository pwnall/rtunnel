# Mocks the sending end of an EventMachine connection.
# The sent data is concatenated in a string available by calling #string.
class EmSendMock
  include RTunnel::FrameProtocol
  
  attr_reader :string
  
  def initialize
    @string = ''
  end
  
  def send_data(data)
    @string += data
  end
end

# Mocks the receiving end of an EventMachine connection.
# The data to be received is passed as an array of strings to the constructor.
# Calling #replay mocks receiving the data.
class EmReceiveMock
  include RTunnel::FrameProtocol
  
  attr_accessor :strings
  attr_accessor :frames
  
  def initialize(strings = [''])
    @strings = strings
    @frames = []
  end
  
  def replay
    @strings.each { |str| receive_data str }
    self
  end
  
  def receive_frame(frame)
    @frames << frame
  end
end
