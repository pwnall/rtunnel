require 'rtunnel'

require 'stringio'
require 'test/unit'

class IOExtensionsTest < Test::Unit::TestCase  
  def setup
    @test_sizes = [0, 1, 10, 127, 128, (1 << 20), (1 << 45) / 3, (1 << 62) / 5]
    @test_strings = ['', 'a',
                     (32..127).to_a.map { |c| c.chr}.join,
                     (32..127).to_a.map { |c| c.chr}.join * 511]
    @str = StringIO.new
  end
  
  def test_varsizes_independent
    @test_sizes.each do |size|
      @str = StringIO.new
      @str.write_varsize size
      @str.rewind
      assert_equal size, @str.read_varsize
    end
  end
 
  def test_varsizes_appended
    @test_sizes.each { |size| @str.write_varsize size }
    @str.rewind
    @test_sizes.each do |size|
      assert_equal size, @str.read_varsize
    end
  end
  
  def test_varsize_error
    @str.write_varsize((1 << 62) / 3)
    vs = @str.string
    0.upto(vs.length - 1) do |truncated_len|
      @str = StringIO.new
      @str.write vs[0, truncated_len]
      @str.rewind
      assert_raise(RTunnel::TruncatedDataError) { @str.read_varsize }
    end
  end
  
  def test_varstring_independent
    @test_strings.each do |str|
      @str = StringIO.new
      @str.write_varstring str
      @str.rewind
      assert_equal str, @str.read_varstring
    end    
  end
  
  def test_varstring_appended
    @test_strings.each { |str| @str.write_varstring str }
    @str.rewind
    @test_strings.each do |str|
       assert_equal str, @str.read_varstring
    end    
  end

  def test_varstring_error
    @str.write_varstring 'This will be truncated'
    vs = @str.string
    0.upto(vs.length - 1) do |truncated_len|
      @str = StringIO.new
      @str.write vs[0, truncated_len]
      @str.rewind
      assert_raise(RTunnel::TruncatedDataError) { @str.read_varstring }
    end
  end
end
