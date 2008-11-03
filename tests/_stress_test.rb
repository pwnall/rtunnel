require 'facets'
require 'facets/random'
require 'net/http'
require 'logger'
require 'stringio'
require 'webrick'

require 'lib/core'

at_exit do
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

CONCURRENT_CONNECTIONS = 20

TUNNEL_SERVER_ADDRESS = "http://localhost:5000"
EXPECTED_DATA = String.random(10*1024)
p :gend_random_data

s = WEBrick::HTTPServer.new(:Port => 4444, :AccessLog => [], :Logger => WEBrick::Log.new(nil, WEBrick::BasicLog::WARN))
s.mount_proc("/") { |req, res| res.body = EXPECTED_DATA; res['Content-Type'] = "text/html" }
Thread.new { s.start }
p :started_webserver

base_dir = File.dirname(__FILE__)

fork{ exec "ruby #{base_dir}/rtunnel_server.rb > /dev/null 2>&1" }
fork{ exec "ruby #{base_dir}/rtunnel_client.rb -c localhost -f 5000 -t 4444 > /dev/null 2>&1" }

p :started_rtunnels

sleep 2

p :slept

STDOUT.sync = true
999999999999.times do |i|
  puts i  if i%10 == 0
  threads = []
  CONCURRENT_CONNECTIONS.times do
    threads << Thread.safe do
      text = Net::HTTP.get(URI.parse(TUNNEL_SERVER_ADDRESS))
      if text != EXPECTED_DATA
        puts "BAD!!!!"*1000
        puts "response: #{text}\nexpected: #{EXPECTED_DATA}\n"
        Process.kill("INT", $$)
      end
    end
  end

  threads.parallel_map {|t| t.join; print '.'; STDOUT.flush }
end
