require 'resolv'

module RTunnel
  VERSION = '0.3.8'
  
  DEFAULT_CONTROL_PORT = 19050
  PING_TIMEOUT = 10
end

if ENV['RTUNNEL_DEBUG']
  def D(msg)
    puts msg
  end
else
  def D(*a);end
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
    raise
  end
end

class IO
  def while_reading(data = nil, &b)
    while buf = readpartial_rescued(1024)
      data << buf  if data
      yield buf  if block_given?
    end
    data
  end

  def readpartial_rescued(size)
    readpartial(size)
  rescue EOFError
    nil
  end
end
