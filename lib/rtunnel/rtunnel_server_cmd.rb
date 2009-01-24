require 'optparse'

require 'rubygems'
require 'eventmachine'


module RTunnel
  def self.run_server    
    options = {}
    
    (opts = OptionParser.new do |o|
      o.on("-c", "--control ADDRESS") { |a| options[:control_address] = a }
      o.on("-a", "--authorized-keys KEYSFILE") do |f|
        options[:authorized_keys] = f
      end
      o.on("-l", "--log-level LEVEL") { |l| options[:log_level] = l }
      o.on("-k", "--keep-alive KEEP_ALIVE_INTERVAL") do |t|
        options[:keep_alive_interval] = t.to_f
      end
      o.on("-p", "--lowest-listen-port PORT") do |p|
        options[:lowest_listen_port] = p.to_i
      end
      o.on("-P", "--highest-listen-port PORT") do |p|
        options[:highest_listen_port] = p.to_i
      end
    end).parse!  rescue (puts opts; return)

    EventMachine::run do
      RTunnel::Server.new(options).start
    end
  end
end
