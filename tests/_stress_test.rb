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

TUNNEL_URI = "http://localhost:#{TUNNEL_PORT}"
EXPECTED_DATA = (0..16*1024).map{rand(?z).chr[/[^_\W]/]||redo}*''  # golf for random data

$pids = [$$]

def cleanup
  puts $!, $@  if $!

  # move the current process to the end of the kill list
  $pids.delete $$
  $pids << $$
  $pids.each {|pid| Process.kill 9, pid  rescue nil }

  exit!
end

at_exit { cleanup }

ENV['RTUNNEL_DEBUG'] = '1'  if DISPLAY_RTUNNEL_OUTPUT

base_dir = File.dirname(__FILE__)
$pids << fork{ exec "ruby", "#{base_dir}/rtunnel_server.rb" }
$pids << fork{ exec "ruby", "#{base_dir}/rtunnel_client.rb", '-c', 'localhost', '-f', TUNNEL_PORT.to_s, '-t', HTTP_PORT.to_s }

$pids << fork do
  require 'thin'

  app = lambda do |env|
    body = env['rack.input'].string 
    if body != EXPECTED_DATA
      p body, EXPECTED_DATA
      puts "server received BAD DATA!"

      cleanup
    end

    [200, {}, EXPECTED_DATA]
  end

  Thin::Server.new('localhost', HTTP_PORT, app).start
end

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
      p EXPECTED_DATA, @data
      puts "client received BAD DATA!"

      cleanup
    end

    print ')'; $stdout.flush

    @@open_connections -= 1
    EventMachine.stop_event_loop  if @@open_connections == 0
  end
end

loop do
  EventMachine.run do
    CONCURRENT_CONNECTIONS.times do
      EventMachine.connect 'localhost', TUNNEL_PORT, Stresser
    end
  end

  puts
end
