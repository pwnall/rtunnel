require 'logger'

module RTunnel
  DEFAULT_CONTROL_PORT = 19050
  PING_TIMEOUT = 10

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
    Thread.new *args do
      begin
        yield
      rescue Exception => e
        E "Worker thread exception - #{e.inspect}"
        D "Stack trace:\n" + e.backtrace.join("\n")
      end  
    end
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
