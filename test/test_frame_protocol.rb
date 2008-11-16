require 'test/unit'

require 'rtunnel'
require 'test/protocol_mocks.rb'

class FrameProtocolTest < Test::Unit::TestCase
  def setup
    super
    @send_mock = EmSendMock.new
  end
  
  def teardown
    super
  end

  def continuous_data_test(frames)
    truncated_data_test frames, []
  end
  
  def truncated_data_test(frames, sub_lengths)
    frames.each { |frame| @send_mock.send_frame frame }
    in_string = @send_mock.string
    in_strings, i = [], 0
    sub_lengths.each do |sublen|
      in_strings << in_string[i, sublen]
      i += sublen
    end
    in_strings << in_string[i..-1] if i < in_string.length
    out_frames = EmReceiveMock.new(@send_mock.string).replay.frames
    assert_equal frames, out_frames
  end

  def test_empty_frame
    continuous_data_test ['']    
  end
  
  def test_byte_frame
    continuous_data_test ['F']
  end

  def test_string_frame
    continuous_data_test [(32...128).to_a.pack('C*')]
  end
  
  def test_multiple_frames
    continuous_data_test [(32...128).to_a.pack('C*'), '', 'F', '', '1234567890']
  end
  
  def test_truncated_border
    truncated_data_test ['A', 'A'], [1, 0, 2, 0]
  end
  
  def test_truncaed_border_and_joined_data_size
    truncated_data_test ['A', 'A'], [1, 1, 1, 1]
  end
  
  def test_truncated_size
    long_frame = (32...128).to_a.pack('C*') * 5
    truncated_data_test [long_frame], [1]
  end

  def test_truncated_size_and_data
    long_frame = (32...128).to_a.pack('C*') * 5
    truncated_data_test [long_frame], [1, 16]
  end
  
  def test_badass
    # TODO(not_me): this test takes 4 seconds; replace with more targeted tests
    
    # build the badass string
    s2_frame = 'qwertyuiopasdfgh' * 8 * 128 # 16384 characters, size is 3 bytes
    @send_mock.send_frame s2_frame
    s2_string = @send_mock.string
    s2_count = 3
    send_string = s2_string * s2_count
    recv_packets = [s2_frame] * s2_count
    
    # build cut points in a string
    s2_points = [0, 1, 2, 3, 4, 5, 127, 128, 8190, 16381, 16382, 16383]
    cut_points = []
    0.upto(s2_count - 1) do |i|
      cut_points += s2_points.map { |p| p + i * s2_string.length }
    end
    
    # try all combinations of cutting up the string in 4 pieces
    0.upto(cut_points.length - 1) do |i|
      (i + 1).upto(cut_points.length - 1) do |j|
        (j + 1).upto(cut_points.length - 1) do |k|
          packets = [0...cut_points[i], cut_points[i]...cut_points[j],
                     cut_points[j]...cut_points[k], cut_points[k]..-1].
                    map { |r| send_string[r] }
          assert_equal recv_packets, EmReceiveMock.new(packets).replay.frames
        end
      end
    end
  end
end