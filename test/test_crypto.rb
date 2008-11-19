require 'rtunnel'

require 'openssl'
require 'test/unit'

class CryptoTest < Test::Unit::TestCase
  C = RTunnel::Crypto
  
  @@rsa_key_path = 'test_data/ssh_host_rsa_key' 
  @@known_hosts_path = 'test_data/known_hosts' 
  
  def test_read_private_key
    key = C.read_private_key @@rsa_key_path
    assert_equal File.read(@@rsa_key_path), key.to_pem
    assert_equal OpenSSL::PKey::RSA, key.class
  end
  
  def test_read_known_hosts_keys
    keys = C.read_known_hosts_keys @@known_hosts_path
    
    assert_equal 3, keys.length
    assert_equal [OpenSSL::PKey::RSA] * 3, keys.map { |k| k.class }
    assert_equal C.read_private_key(@@rsa_key_path).public_key.to_pem,
                 keys[1].to_pem
  end
  
  def test_key_fingerprint
    keys = C.read_known_hosts_keys @@known_hosts_path

    assert_equal 3, keys.map { |k| C.key_fingerprint k }.uniq.length
    keys.each { |k| assert_equal C.key_fingerprint(k), C.key_fingerprint(k) }
  end
  
  def test_load_public_keys
    keyset = C.load_public_keys @@known_hosts_path
    rsa_key = C.read_private_key @@rsa_key_path
    
    assert_equal rsa_key.public_key.to_pem,
                 keyset[C.key_fingerprint(rsa_key)].to_pem
  end
end