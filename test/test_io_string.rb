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
