require 'digest/sha2'
require 'openssl'
require 'stringio'

require 'rubygems'
require 'net/ssh'

module RTunnel::Crypto
  # Reads all the keys from an openssh known_hosts or authorized_keys2 file.
  def self.read_authorized_keys(file_name)
    keys = []
    File.read(file_name).each_line do |line|
      pubkey_match = /ssh-\w*\s*(\S*)/.match line
      next unless pubkey_match
      pubkey_blob = pubkey_match[1].unpack('m*').first      
      keys << Net::SSH::Buffer.new(pubkey_blob).read_key
    end
    return keys
  end
  
  # Loads a private key from an openssh key file.
  def self.read_private_key(file_name)
    Net::SSH::KeyFactory.load_private_key file_name
  end
  
  # Computes a string that represents the key. Different keys should
  # map out to different fingerprints.
  def self.key_fingerprint(key)
    key.public_key.to_der
  end
  
  # Encrypts some data with a public key. The matching private key will be
  # required to decrypt the data.
  def self.encrypt_with_key(key, data)
    if key.kind_of? OpenSSL::PKey::RSA
      key.public_encrypt data, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING
    elsif key.kind_of? OpenSSL::PKey::DSA
      key.public_encrypt encrypted_data
    else
      raise 'Unsupported key type'
    end
  end
  
  # Decrypts data that was previously encrypted with encrypt_with_key.
  def self.decrypt_with_key(key, encrypted_data)
    if key.kind_of? OpenSSL::PKey::RSA
      key.private_decrypt encrypted_data, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING    
    elsif key.kind_of? OpenSSL::PKey::DSA
      key.private_decrypt encrypted_data
    else
      raise 'Unsupported key type'
    end
  end
  
  # Loads public keys to be used by a server.
  def self.load_public_keys(file_name)
    key_list = read_authorized_keys file_name
    RTunnel::Crypto::KeySet.new key_list
  end
end

# A set of keys used by a server to authenticate clients.
class RTunnel::Crypto::KeySet  
  def initialize(key_list)
    @keys_by_fp = {}
    key_list.each { |k| @keys_by_fp[RTunnel::Crypto.key_fingerprint(k)] = k }    
  end
  
  def [](key_fp)
    @keys_by_fp[key_fp]
  end
  
  def length
    @keys_by_fp.length
  end
end

# A cryptographically secure hasher. Instances will hash the data 
class RTunnel::Crypto::Hasher
  attr_reader :key
  
  def initialize(key = nil)
    @key = key || RTunnel::Crypto::Hasher.random_key
    @cipher = OpenSSL::Cipher::Cipher.new 'aes-128-cbc'
    @cipher.encrypt
    iokey = StringIO.new @key
    @cipher.key = iokey.read_varstring
    @cipher.iv = iokey.read_varstring
  end

  # Creates a hash for the given data. Warning: this method is not idempotent.
  # The intent is that the same hash can be produced by another hasher that is
  # initialized with the same key and has been fed the same data.
  def hash(data)
    @cipher.update Digest::SHA2.digest(data)
  end

  # Produces a random key for the hasher.
  def self.random_key
    cipher = OpenSSL::Cipher::Cipher.new 'aes-128-cbc'
    iokey = StringIO.new
    iokey.write_varstring cipher.random_key
    iokey.write_varstring cipher.random_iv
    return iokey.string
  end  
end