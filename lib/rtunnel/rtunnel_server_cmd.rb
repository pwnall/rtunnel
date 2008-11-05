require 'optparse'

module RTunnel
  def self.run_server    
    options = {}
    
    (opts = OptionParser.new do |o|
      o.on("-c", "--control ADDRESS") { |a| options[:control_address] = a }
    end).parse!  rescue (puts opts; return)

    RTunnel::Server.new(options).start.join
  end  
end
