require File.dirname(__FILE__) + '/spec_helper'

require 'client'
require 'server'

describe "RTunnel" do
  class TextServer < GServer
    def initialize(port, text)
      @text = text
      super(port)
    end

    def serve(io)
      io.write(@text)
    end
  end

  def read_from_address(addr)
    timeout(2) { TCPSocket.open(*addr.split(/:/)) {|s| s.read } }
  end

  it "should work!" do
    begin
      server = RTunnel::Server.new(:control_address => 'localhost:9999')
      client = RTunnel::Client.new(:control_address => 'localhost:9999', :remote_listen_address => '30002', :tunnel_to_address => '30003')

      server.start
      client.start

      s = TextServer.new(30003, echo_text = "tunnel this txt plz!")
      s.start

      sleep 0.5

      # direct connect (sanity check)
      read_from_address('localhost:30003').should == echo_text
      # tunneled connect
      read_from_address('localhost:30002').should == echo_text
    ensure
      begin
        client.stop
        server.stop
        s.stop
      rescue
      end
    end
  end

  it "should ping all clients periodically" do
    begin
      server = RTunnel::Server.new(:control_address => 'localhost:9999', :ping_interval => 0.2)
      clients = []
      clients << RTunnel::Client.new(:control_address => 'localhost:9999', :remote_listen_address => '30002', :tunnel_to_address => '30003')
      clients << RTunnel::Client.new(:control_address => 'localhost:9999', :remote_listen_address => '30012', :tunnel_to_address => '30013')
      server.start
      clients.each{|c|c.start}

      pings = Hash.new {|h,k| h[k] = [] }
      t = Thread.new do
        loop do
          clients.each do |client|
            pings[client] << client.instance_eval { @last_ping }
          end
          sleep 0.05
        end
      end

      sleep 2

      clients.each do |client|
        # 2 seconds, 0.2 pings a sec = ~10 pings
        (9..11).should include(pings[client].uniq.size)
      end
    ensure
      t.kill
      begin
        clients.each{|c|c.stop}
        server.stop
      rescue
        p $!,$@
      end
    end
  end

  it "the client shouldnt fail even if there is no server running at the tunnel_to address" do
    begin
      server = RTunnel::Server.new(:control_address => 'localhost:9999')
      client = RTunnel::Client.new(:control_address => 'localhost:9999', :remote_listen_address => '30002', :tunnel_to_address => '30003')

      server.start
      client.start

      sleep 0.5

      # tunneled connect
      read_from_address('localhost:30002').should be_empty
    ensure
      begin
        client.stop
        server.stop
      rescue
      end
    end
  end
end
