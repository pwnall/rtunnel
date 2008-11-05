#!/usr/bin/ruby

module RTunnel
  def run_server    
    control_address = tunnel_port = nil
    
    (opts = OptionParser.new do |o|
      o.on("-c", "--control ADDRESS") { |a| control_address = a }
    end).parse!  rescue (puts opts; exit)
    
    server = RTunnel::Server.new(
      :control_address => control_address
    )
    
    server.start
    server.join
  end  
end
