require 'optparse'

require 'rubygems'
require 'eventmachine'


module RTunnel
  def self.run_server    
    options = {}
    
    (opts = OptionParser.new do |o|
      o.on("-c", "--control ADDRESS") { |a| options[:control_address] = a }
      o.on("-l", "--log-level LEVEL") { |l| options[:log_level] = l }
    end).parse!  rescue (puts opts; return)

    EventMachine::run do
      RTunnel::Server.new(options).start
    end
  end
end
