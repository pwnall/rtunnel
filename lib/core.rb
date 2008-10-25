module RTunnel
  VERSION = '0.3.8'
  
  DEFAULT_CONTROL_PORT = 19050
  PING_TIMEOUT = 10
end


def D(msg)
  puts msg  if $debug
end

class << Thread
  def safe(*a)
    Thread.new(*a) do
      begin
        yield
      rescue Exception
        puts $!.inspect
        puts $!.backtrace.join("\n")
      end  
    end
  end
end

class String
  def replace_with_ip!
    host = self.split(/:/).first

    ip = timeout(5) { Resolv.getaddress(host) }

    self.replace(self.gsub(host, ip))
  rescue Exception
    puts "Error resolving #{host}"
    exit
  end
end

class IO
  def read_or_timeout(timeout = 5, read_size = 1024)
    data = timeout(timeout) { self.read(read_size) }
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
