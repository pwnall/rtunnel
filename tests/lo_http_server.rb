require 'net/http'
require 'socket'
require 'time'

require 'rubygems'
require 'simple-daemon'
  
class LoHttpServer < SimpleDaemon::Base
  def send_headers(socket, status, length = 0, mime_type = 'text/html', headers = {})
    reason = headers[:reason] || {200 => 'OK', 404 => 'File not found'}[status]
    
    response_line = "HTTP/1.1 #{status} #{reason}\r\n"    

    response_headers = { 'Connection' => 'close', 'Server' => 'Rubylicious/1.0', 'Date' => Time.now.rfc2822,
      'Content-Type' => mime_type, 'Content-Length' => length }.merge headers

    socket.write response_line
    socket.write response_headers.to_a.map { |k,v| k.to_s + ': ' + v.to_s }.join("\r\n") + "\r\n\r\n"
  end
  
  def send_html(socket, html_data = "Loopback page\n")
    send_headers(socket, 200, html_data.length)
    socket.write html_data
    socket.close
  end

  def run(listen_port)
    listen_socket = TCPServer.new listen_port
    
    loop do
      client_socket = listen_socket.accept
      Thread.new do
        begin
          print client_socket.readpartial(16384), "\n"          
          send_html client_socket
        rescue
          print "#{$!.class.name}: #{$!}\n"
          print $!.backtrace.join("\n"), "\n"
        end
      end
    end    
  end
  
  SimpleDaemon::WORKING_DIRECTORY = File.dirname(__FILE__)

  def self.start
    port = ARGV[1] || 3000
    self.new.run(port)    
  end

  def self.stop
  end
end

LoHttpServer.daemonize
