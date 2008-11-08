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
    @log = Logger.new STDERR
    @log.level = Logger::DEBUG
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

  # creates a thread that will not die silently if an error occurs;
  # the error will be logged 
  def logged_thread(*args)
    Thread.new *args do |*thread_args|
      begin
        yield *thread_args
      rescue Exception => e
        E "Worker thread exception - #{e.inspect}"
        D "Stack trace:\n" + e.backtrace.join("\n")
      end  
    end
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

class IO
  def read_or_timeout(timeout = 5, read_size = 1024)
    timeout(timeout) { self.read(read_size) }
  rescue Timeout::Error
    ''
  rescue
    nil
  end
end

class UUID
  def self.t
    timestamp_create.hexdigest
  end
end
