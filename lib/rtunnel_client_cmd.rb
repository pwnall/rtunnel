#!/usr/bin/ruby

$LOAD_PATH << 'lib'

require 'client'

control_address = tunnel_from_address = tunnel_to_address = remote_listen_address = nil

(opts = OptionParser.new do |o|
  o.on("-c", "--control-address ADDRESS") { |a| control_address = a }
  o.on("-f", "--remote-listen-port ADDRESS") { |a| remote_listen_address = a }
  o.on("-t", "--tunnel-to ADDRESS") { |a| tunnel_to_address = a }
end).parse!  rescue (puts opts; exit)

(puts opts; exit)  if [control_address, remote_listen_address, tunnel_to_address].include? nil

client = RTunnel::Client.new(
  :control_address => control_address,
  :remote_listen_address => remote_listen_address,
  :tunnel_to_address => tunnel_to_address
)
client.start
client.join
