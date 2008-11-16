require 'logger'

module RTunnel
  DEFAULT_CONTROL_PORT = 19050
  PING_TIMEOUT = 10
  PING_INTERVAL = 2

  class AbortProgramException < Exception
    
  end
end

module RTunnel::Logging
  def init_log(options = {})
    # TODO(costan): parse logging options
    if options[:to]
      @log = options[:to].instance_variable_get(:@log).dup
    else
      @log = Logger.new(STDERR)
      @log.level = Logger::ERROR
    end
    if options[:level]
      @log.level = Logger::const_get(options[:level].upcase.to_sym)
    end
  end
  
  def D(message)
    @log.debug message
  end
  
  def W(message)
    @log.warn message
  end
  
  def I(message)
    @log.info message
  end
  
  def E(message)
    @log.error message
  end
  
  def F(message)
    @log.fatal message
  end
end

module RTunnel
  # Resolve the given address to an IP.
  # The address can have the following formats: host; host:port; ip; ip:port;
  def self.resolve_address(address, timeout_sec = 5)
    host, rest = address.split(':', 2)
    ip = timeout(timeout_sec) { Resolv.getaddress(host) }
    return rest ? "#{ip}:#{rest}" : ip
  rescue Exception
    raise AbortProgramException, "Error resolving #{host}" 
  end  
end
