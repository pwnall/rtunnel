require 'rtunnel'

require 'openssl'
require 'test/unit'

class CryptoTest < Test::Unit::TestCase
  C = RTunnel::Crypto
  
  @@rsa_key_path = 'test_data/ssh_host_rsa_key' 
  @@dsa_key_path = 'test_data/ssh_host_dsa_key' 
  @@known_hosts_path = 'test_data/known_hosts' 
  
  def test_read_private_key
    key = C.read_private_key @@rsa_key_path
    assert_equal File.read(@@rsa_key_path), key.to_pem
    assert_equal OpenSSL::PKey::RSA, key.class

    key = C.read_private_key @@dsa_key_path
    assert_equal File.read(@@dsa_key_path), key.to_pem
    assert_equal OpenSSL::PKey::DSA, key.class
  end
  
  def test_read_known_hosts_keys
    keys = C.read_known_hosts_keys @@known_hosts_path
    
    assert_equal 4, keys.length
    assert_equal [OpenSSL::PKey::RSA] * 3 + [OpenSSL::PKey::DSA],
                 keys.map { |k| k.class }
    assert_equal C.read_private_key(@@rsa_key_path).public_key.to_pem,
                 keys[1].to_pem
    assert_equal C.read_private_key(@@dsa_key_path).public_key.to_pem,
                 keys[3].to_pem
  end
  
  def test_key_fingerprint
    keys = C.read_known_hosts_keys @@known_hosts_path

    assert_equal 4, keys.map { |k| C.key_fingerprint k }.uniq.length
    keys.each { |k| assert_equal C.key_fingerprint(k), C.key_fingerprint(k) }
  end
  
  def test_load_public_keys
    keyset = C.load_public_keys @@known_hosts_path
    rsa_key = C.read_private_key @@rsa_key_path
    dsa_key = C.read_private_key @@dsa_key_path
    
    assert_equal rsa_key.public_key.to_pem,
                 keyset[C.key_fingerprint(rsa_key)].to_pem
    assert_equal dsa_key.public_key.to_pem,
                 keyset[C.key_fingerprint(dsa_key)].to_pem
  end
  
  def test_key_encryption
    test_data = 'qwertyuiopasdfghjklzxcvbnm' * 2
    rsa_key = C.read_private_key @@rsa_key_path
    dsa_key = C.read_private_key @@rsa_key_path
    
    [rsa_key, dsa_key].each do |key|
      encrypted_data = C.encrypt_with_key key.public_key, test_data
      decrypted_data = C.decrypt_with_key key, encrypted_data
      
      assert_equal test_data, decrypted_data
      0.upto(test_data.length - 4) do |i|
        assert !encrypted_data.index(test_data[i, 4]),
               'Encryption did not wipe the original pattern'
      end
    end
  end
  
  def test_encryption_depends_on_key
    num_keys = 16
    test_data = 'qwertyuiopasdfghjklzxcvbnm' * 2
    keys = (0...num_keys).map { OpenSSL::PKey::RSA.generate 1024, 35 }
    assert_equal num_keys, keys.map { |k| C.encrypt_with_key k, test_data }.
                                uniq.length
  end
end