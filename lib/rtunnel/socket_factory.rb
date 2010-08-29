require 'socket'

module RTunnel::SocketFactory
  def self.split_address(address)
    host_port, bind_address = *address.split('@', 2)
    port_index = host_port.index /[^:]\:[^:]/
    host, port = *(if port_index
      [host_port[0, port_index + 1], host_port[port_index + 2, address.length]]
    else
      [address, nil]
    end)
    [host, port, bind_address]
  end
  
  def self.host_from_address(address)
    address and split_address(address)[0]
  end
  
  def self.port_from_address(address)
    address and (port_string = split_address(address)[1]) and port_string.to_i
  end

  def self.bind_host_from_address(address)
    address and split_address(address)[2]
  end
  
  def self.inbound?(options)
    options[:inbound] or [:in_port, :in_host, :in_addr].any? { |k| options[k] }
  end
  
  def self.bind_host(options)
    options[:in_host] or host_from_address(options[:in_addr]) or '0.0.0.0'
  end
  
  def self.bind_port(options)
    options[:in_port] or port_from_address(options[:in_addr]) or 0
  end
  
  def self.bind_socket_address(options)
    Socket::pack_sockaddr_in bind_port(options), bind_host(options)
  end
  
  def self.connect_host(options)
    options[:out_host] or host_from_address(options[:out_addr])
  end
  
  def self.connect_port(options)
    options[:out_port] or port_from_address(options[:out_addr])
  end
  
  def self.connect_socket_address(options)
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
      if socket.respond_to? :do_not_reverse_lookup
        socket.do_not_reverse_lookup = true
      else
        # work around until the patch below actually gets committed:
        # http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-core/2346
        BasicSocket.do_not_reverse_lookup = true
      end
    end
  end

  # new sockets coming out of socket.accept will have the given options set
  def self.set_options_on_accept_sockets(socket, options)
    socket.instance_variable_set :@rtunnel_factory_options, options
    def socket.accept(*args)
      sock, addr = super
      RTunnel::SocketFactory.set_options sock, @rtunnel_factory_options
      return sock, addr
    end
  end
  
  def self.socket(options = {})    
    s = new_socket options
    set_options s, options
    if inbound? options
      bind s, options    
      set_options_on_accept_sockets s, options
    else
      connect s, options
    end
    s
  end
  
  def socket(options = {})
    RTunnel::SocketFactory.socket(options)
  end  
end
