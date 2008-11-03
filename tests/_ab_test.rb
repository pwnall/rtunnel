#require 'facets'
require 'net/http'
require 'logger'
require 'stringio'
require 'webrick'

require 'lib/core'

puts "make sure a fast responding webserver is started on port 4000"

base_dir = File.dirname(__FILE__)

fork{ exec "ruby #{base_dir}/rtunnel_server.rb > /dev/null 2>&1" }
fork{ exec "ruby #{base_dir}/rtunnel_client.rb -c localhost -f 5000 -t 4000 > /dev/null" }

sleep 2

(puts "you need ab (apache bench) to run this stress test" ; exit) if %x{which ab}.empty?

Process.wait fork { exec("ab -c 500 -n 10000 http://localhost:5000/") }

puts "done, hit ^C"
sleep 999999
