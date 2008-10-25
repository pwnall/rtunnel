require File.dirname(__FILE__) + '/spec_helper'

require 'server'

include RTunnel
describe RTunnel::Server, "addresses" do
  it "control address should listen on all interfaces and use default control port if not specified" do
    Server.new(:control_address => nil).
      instance_eval { @control_address }.should == "0.0.0.0:#{DEFAULT_CONTROL_PORT}"

    Server.new(:control_address => '5555').
      instance_eval { @control_address }.should == "0.0.0.0:5555"

    Server.new(:control_address => 'interface2').
      instance_eval { @control_address }.should == "interface2:#{DEFAULT_CONTROL_PORT}"

    Server.new(:control_address => 'interface2:2222').
      instance_eval { @control_address }.should == "interface2:2222"
  end

end