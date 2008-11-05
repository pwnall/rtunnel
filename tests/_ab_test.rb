base_dir = File.dirname(__FILE__)
lo_server_file = File.join(base_dir, '../tests/lo_http_server.rb')
lo_port = 4000
Kernel.system "ruby #{lo_server_file} start #{lo_port}"

fork{ exec "ruby #{base_dir}/../lib/rtunnel/rtunnel_server.rb > /dev/null 2>&1" }
fork{ exec "ruby #{base_dir}/../lib/rtunnel/rtunnel_client.rb -c localhost -f 5000 -t 4000 > /dev/null" }

sleep 2

(puts "you need ab (apache bench) to run this stress test" ; exit) if %x{which ab}.empty?

Process.wait fork { exec("ab -c 500 -n 10000 http://localhost:5000/") }

puts "done, hit ^C"
sleep 999999
