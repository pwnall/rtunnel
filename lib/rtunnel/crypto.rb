require 'openssl'

require 'rubygems'
require 'net/ssh'

module RTunnel::Crypto
  # Reads all the keys from an openssh known_hosts file.
  # If no file name is given, the default ~/.ssh/known_hosts will be used.
  def self.read_known_hosts_keys(file_name = nil)
    if file_name
      Net::SSH::KnownHosts.search_in file_name, ''
    else
      Net::SSH::KnownHosts.search_for ''
    end
  end
  
  # Loads a private key from an openssh key file.
  def self.read_private_key(file_name = nil)
    Net::SSH::KeyFactory.load_private_key file_name
  end
  
  # Computes a string that represents the key. Different keys should
  # map out to different fingerprints.
  def self.key_fingerprint(key)
    key.public_key.to_der
  end
  
  # Loads public keys to be used by a server.
  def self.load_public_keys(file_name = nil)
    key_list = read_known_hosts_keys file_name
    RTunnel::Crypto::KeySet.new key_list
  end
end

# A set of keys used by a server to authenticate clients.s
class RTunnel::Crypto::KeySet  
  def initialize(key_list)
    @keys_by_fp = {}
    key_list.each { |k| @keys_by_fp[RTunnel::Crypto.key_fingerprint(k)] = k }    
  end
  
  def [](key_fp)
    @keys_by_fp[key_fp]
  end
end