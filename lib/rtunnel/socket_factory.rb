require 'socket'

module RTunnel::SocketFactory  
  def self.inbound?(options)
    options[:inbound] or options[:in_port] or options[:in_addr]
  end
  
  def self.bind_host(options)
    options[:in_host] or options[:in_addr].split(':').first or
        '0.0.0.0'
  end
  
  def self.bind_port(options)
    options[:in_port] or options[:in_addr].split(':').last or 0
  end
  
  def self.bind_socket_address(options)
    Socket::pack_sockaddr_in bind_port(options), bind_host(options)
  end
  
  def self.connect_host(options)
    options[:out_host] or options[:out_addr].split(':').first
  end
  
  def self.connect_port(options)
    options[:out_port] or options[:out_addr].split(':').last
  end
  
  def self.connect_socket_address
    Socket::pack_sockaddr_in connect_port(options), connect_host(options)
  end
  
  def self.tcp?(options)
    options[:tcp] or !options[:udp]
  end
  
  def self.new_tcp_socket
    Socket.new Socket::AF_INET, Socket::SOCK_STREAM, Socket::PF_UNSPEC
  end
  
  def self.new_udp_socket
    Socket.new Socket::AF_INET, Socket::SOCK_DGRAM, Socket::PF_UNSPEC
  end
  
  def self.new_socket(options)
    tcp?(options) ? new_tcp_socket : new_udp_socket
  end
  
  def self.bind(socket, options)
    socket.bind bind_socket_address(options)
  end
  
  def self.connect(socket, options)
    socket.connect connect_socket_address(options)
  end
  
  def self.set_options(socket, options)
    if options[:no_delay]
      socket.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true
      socket.sync = true
    end
    
    if options[:reuse_addr]
      socket.setsockopt Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true
    end
    
    unless options[:reverse_lookup]
      socket.do_not_reverse_lookup
    end
  end

  # new sockets coming out of socket.listen will have the given options set
  def self.set_options_on_listen_sockets(socket, options)
    class << socket
      def listen(*args)
        s = super
        RTunnel::SocketFactory.set_options s, options
        return s
      end
    end
  end
  
  def self.socket(options = {})    
    s = new_socket options
    set_options s, options
    if inbound? options
      bind s, options    
      set_options_on_listen_sockets s
    else
      connect s, options
    end
  end
  
  def socket(options = {})
    RTunnel::SocketFactory.socket(options)
  end  
end
