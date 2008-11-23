require 'base64'
require 'openssl'

# Unique ID generation functionality.
module RTunnel::ConnectionId
  def self.new_cipher
    cipher = OpenSSL::Cipher::Cipher.new 'aes-128-ecb'
    cipher.encrypt
    cipher.key, cipher.iv = cipher.random_key, cipher.random_iv
    cipher
  end
  
  def self.new_counter
    '0' * 16
  end
  
  def new_connection_id
    @session_id_cipher ||= RTunnel::ConnectionId.new_cipher
    @session_id_counter ||= RTunnel::ConnectionId.new_counter
    connection_id = @session_id_cipher.update @session_id_counter
    @session_id_counter.succ!
    Base64.encode64(connection_id).strip
  end
end