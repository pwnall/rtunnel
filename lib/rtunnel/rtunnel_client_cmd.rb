require 'optparse'

require 'rubygems'
require 'eventmachine'

module RTunnel
  def self.run_client
    options = {}
    
    (opts = OptionParser.new do |o|
      o.on("-c", "--control-address ADDRESS") do |a|
        options[:control_address] = a
      end
      o.on("-f", "--remote-listen-port ADDRESS") do |a|
        options[:remote_listen_address] = a
      end
      o.on("-t", "--tunnel-to ADDRESS") do |a|
        options[:tunnel_to_address] = a
      end
    end).parse!  rescue (puts opts; return)
    
    mandatory_keys = [:control_address, :remote_listen_address,
                      :tunnel_to_address]
                      
    (puts opts; return) unless mandatory_keys.all? { |key| options[key] }
    
    EventMachine::run do
      RTunnel::Client.new(options).start
    end
  end
end
