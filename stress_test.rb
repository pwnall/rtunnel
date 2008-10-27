require 'rubygems'
require 'thin'

require 'lib/core'

require 'logger'
require 'stringio'


CONCURRENT_CONNECTIONS = 25
DISPLAY_RTUNNEL_OUTPUT = false
TUNNEL_PORT = 5000
HTTP_PORT = 4444

#################

pids = []
at_exit do
  pids.each {|pid| Process.kill 9, pid }
  p $!
  puts "done, hit ^C"
  sleep 999999
end

module Enumerable
  def parallel_map
    self.map do |e|
      Thread.new(e) do |element|
        yield element
      end
    end.map {|thread| thread.value }
  end
end

TUNNEL_URI = "http://localhost:#{TUNNEL_PORT}"
EXPECTED_DATA = (0..10*1024).map{0until(c=rand(?z).chr)=~/(?!_)\w/;c}*'' # gen random string GOLF FTW!
puts EXPECTED_DATA

app = lambda { |env| [200, {}, EXPECTED_DATA] }
server = ::Thin::Server.new('localhost', HTTP_PORT, app)
Thread.new { server.start }

base_dir = File.dirname(__FILE__)

d = !DISPLAY_RTUNNEL_OUTPUT
pids << fork{ exec "ruby #{base_dir}/rtunnel_server.rb #{d && '> /dev/null'} 2>&1" }
pids << fork{ exec "ruby #{base_dir}/rtunnel_client.rb -c localhost -f #{TUNNEL_PORT} -t #{HTTP_PORT} #{d &&' > /dev/null'} 2>&1" }

puts 'wait 2 secs'
sleep 2

STDOUT.sync = true
999999999.times do |i|
  puts i  if i%10 == 0
  threads = []
  CONCURRENT_CONNECTIONS.times do
    threads << Thread.new do
      text = %x{curl --silent #{TUNNEL_URI}}
      if text != EXPECTED_DATA
        puts "BAD!!!!"*1000
        puts "response: #{text.inspect}"
        exit
      end
    end
  end

  threads.parallel_map {|t| t.join; print '.'; STDOUT.flush }
end
