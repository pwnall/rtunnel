require 'rubygems'

require 'mongrel'
require 'facets'
require 'facets/random'
require 'logger'
require 'stringio'

require 'lib/core'

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

CONCURRENT_CONNECTIONS = 25

TUNNEL_PORT = 5000
HTTP_PORT = 4444
TUNNEL_URI = "http://localhost:#{TUNNEL_PORT}"
EXPECTED_DATA = String.random(10*1024)

puts EXPECTED_DATA.inspect

p :gend_random_data

require 'thin'
app = lambda { |env| [200, {}, EXPECTED_DATA] }
server = ::Thin::Server.new('localhost', HTTP_PORT, app)
Thread.new { server.start }

p :started_stressed_server

base_dir = File.dirname(__FILE__)

pids << fork{ exec "ruby #{base_dir}/rtunnel_server.rb > /dev/null 2>&1" }
pids << fork{ exec "ruby #{base_dir}/rtunnel_client.rb -c localhost -f #{TUNNEL_PORT} -t #{HTTP_PORT} > /dev/null 2>&1" }

p :started_rtunnels

sleep 2

p :slept

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
