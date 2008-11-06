require 'rubygems'
require 'eventmachine'
require 'logger'
require 'stringio'

require 'lib/core'

CONCURRENT_CONNECTIONS = 5
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

TUNNEL_URI = "http://localhost:#{TUNNEL_PORT}"
EXPECTED_DATA = (0..16*1024).map{rand(?z).chr[/[^_\W]/]||redo}*''

pid = $$
fork do
  require 'thin'
  app = lambda do |env|
    body = env['rack.input'].string 
    if body != EXPECTED_DATA
      puts "received BAD DATA!"
      p body, EXPECTED_DATA
      Process.kill 9, $$
      exit!
    end

    [200, {}, EXPECTED_DATA]
  end
  Thin::Server.new('localhost', HTTP_PORT, app).start
end

base_dir = File.dirname(__FILE__)

d = !DISPLAY_RTUNNEL_OUTPUT
pids << fork{ exec "ruby #{base_dir}/rtunnel_server.rb #{d && '> /dev/null'} 2>&1" }
pids << fork{ exec "ruby #{base_dir}/rtunnel_client.rb -c localhost -f #{TUNNEL_PORT} -t #{HTTP_PORT} #{d &&' > /dev/null'} 2>&1" }

puts 'wait 2 secs...'
sleep 2

module Stresser
  @@open_connections = 0

  def post_init
    @@open_connections += 1
    send_data "POST / HTTP/1.0\r\nContent-Length: #{EXPECTED_DATA.size}\r\n\r\n#{EXPECTED_DATA}"
    @data = ''
    print '('; $stdout.flush
  end

  def receive_data(data)
    @data << data
    print '.'; $stdout.flush
  end

  def unbind
    if @data.gsub(/\A.+\r\n\r\n/m,'') != EXPECTED_DATA
      puts "BAD DATA!"
      puts "response: #{@data.inspect}"
      exit!
    end

    print ')'; $stdout.flush

    @@open_connections -= 1
    EventMachine.stop_event_loop  if @@open_connections == 0
  end
end

$stdout.sync = true
loop do
  EventMachine.run do
    CONCURRENT_CONNECTIONS.times do
      EventMachine.connect 'localhost', TUNNEL_PORT, Stresser
    end
  end
  puts
end
