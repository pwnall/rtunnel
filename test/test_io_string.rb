require 'rtunnel'
require 'test/unit'

class IOStringTest < Test::Unit::TestCase
  def setup
    @str = RTunnel::IOString.new
  end
  
  def test_empty_read
    3.times { assert_equal nil, @str.getc }
    
    3.times { assert_equal '', @str.read }
    3.times { assert_equal nil, @str.read(1) }
  end
  
  def test_read
    @str << 'Randomness'
    assert_equal 'Random', @str.read(6)
    assert_equal 'ness', @str.read(10)
  end
  
  def test_writes_reads
    @str << '123'
    @str << '4567'
    assert_equal '12345', @str.read(5)
    @str << '89'
    assert_equal '678', @str.read(3)
    assert_equal '9', @str.read(5)
    @str << 'abcdef'
    assert_equal 'ab', @str.read(2)
    @str << 'ghi'
    assert_equal 'cdef', @str.read(4)
    assert_equal 'gh', @str.read(2)
    assert_equal 'i', @str.read(2)
  end
  
  def test_null
    3.times do 
      @str.write "\000"
      assert_equal "\000", @str.read(1)
    end
  end
  
  def test_constructor_getc_and_reads
    @str = RTunnel::IOString.new "1234"
    assert_equal ?1, @str.getc
    assert_equal "23", @str.read(2)
    assert_equal ?4, @str.getc
    assert_equal nil, @str.getc
  end
end

class IOExtensionsTest < Test::Unit::TestCase  
  def setup
    @test_sizes = [0, 1, 10, 127, 128, (1 << 20), (1 << 45) / 3, (1 << 62) / 5]
    @test_strings = ['', 'a',
                     (32..127).to_a.map { |c| c.chr}.join,
                     (32..127).to_a.map { |c| c.chr}.join * 511]
    @str = RTunnel::IOString.new    
  end
  
  def test_varsizes_independent
    @test_sizes.each do |size|
      @str = RTunnel::IOString.new
      @str.write_varsize size
      assert_equal size, @str.read_varsize
    end
  end
 
  def test_varsizes_appended
    @test_sizes.each { |size| @str.write_varsize size }
    @test_sizes.each do |size|
      assert_equal size, @str.read_varsize
    end
  end
  
  def test_varsize_error
    @str.write_varsize((1 << 62) / 3)
    vs = @str.read
    0.upto(vs.length - 1) do |truncated_len|
      @str.append vs[0, truncated_len]
      assert_raise(RuntimeError) { @str.read_varsize }
    end
  end
  
  def test_varstring_independent
    @test_strings.each do |str|
      @str = RTunnel::IOString.new
      @str.write_varstring str
      assert_equal str, @str.read_varstring
    end    
  end
  
  def test_varstring_appended
    @test_strings.each { |str| @str.write_varstring str }
    @test_strings.each do |str|
       assert_equal str, @str.read_varstring
    end    
  end

  def test_varsize_error
    @str.write_varsize((1 << 62) / 3)
    vs = @str.read
    @str.append vs[0, vs.length - 1]
    assert_raise(RuntimeError) { @str.read_varsize }
  end
end

class ThreadedIOStringTest < Test::Unit::TestCase
  def setup
    @str = RTunnel::ThreadedIOString.new
  end
  
  def test_empty_read
    @str.writer_close

    3.times { assert_equal nil, @str.getc }
    
    3.times { assert_equal '', @str.read }
    3.times { assert_equal nil, @str.read(1) }    
  end
  
  def test_write_read
    @str << '12345'
    assert_equal '123', @str.read(3)
    assert_equal '4', @str.read(1)
    @str.writer_close
    assert_equal '5', @str.read
  end
  
  def test_threaded_write_read
    Thread.new do
      @str << '123'
      sleep 0.1
      @str << '456'
      sleep 0.1
      @str << '789'
    end
    
    assert_equal '12', @str.read(2)
    assert_equal '345', @str.read(3)
    assert_equal '678', @str.read(3)
    2.times { assert_raise(TimeoutError) { timeout(0.2) { @str.read(2) } } }
    @str.writer_close
    assert_equal '9', @str.read(3)
  end
end
