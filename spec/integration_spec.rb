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
    timeout(2) { TCPSocket.new(*addr.split(/:/)).read }
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
        server.stop
        client.stop
        s.stop
      rescue
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
        server.stop
        client.stop
      rescue
      end
    end

  end

end