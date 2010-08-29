require File.expand_path('../test_helper.rb', __FILE__)

class ConnectionIdTest < Test::Unit::TestCase
  class CidWrapper
    include RTunnel::ConnectionId
  end

  def setup
    @server = CidWrapper.new
  end

  def test_ids_are_unique
    n_ids = 1024
    ids = (0...n_ids).map { @server.new_connection_id }
    assert_equal n_ids, ids.uniq.length
  end
    
  def test_id_sequences_are_not_trivial
    n_servers = 256
    n_ids = 16
    sequences = (0...n_servers).map { CidWrapper.new }.map do |server|
      (0...n_ids).map { server.new_connection_id }
    end
    0.upto(n_ids - 1) do |i|
      assert_equal n_servers, sequences.map { |seq| seq[i] }.uniq.length
    end
  end
end