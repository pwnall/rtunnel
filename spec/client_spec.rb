require File.dirname(__FILE__) + '/spec_helper'

require 'client'

include RTunnel
describe RTunnel::Client, "addresses" do
  def o(opts)
    {:control_address => 'x.com', :remote_listen_address => '5555', :tunnel_to_address => '6666'}.merge opts
  end

  before :all do
    String.class_eval do
      alias_method :orig_replace_with_ip!, :replace_with_ip!
      define_method :replace_with_ip! do
        self
      end
    end
  end

  after :all do
    String.class_eval do
      alias_method :replace_with_ip!, :orig_replace_with_ip!
    end
  end

  it "should use default control port if not specified" do
    Client.new(o :control_address => 'asdf.net').
      instance_eval { @control_address }.should == "asdf.net:#{DEFAULT_CONTROL_PORT}"

    Client.new(o :control_address => 'asdf.net:1234').
      instance_eval { @control_address }.should == "asdf.net:1234"
  end

  it "should use 0.0.0.0 for remote listen host if not specified" do
    Client.new(o :control_address => 'asdf.net:1234', :remote_listen_address => '8888').
      instance_eval { @remote_listen_address }.should == '0.0.0.0:8888'

    Client.new(o :control_address => 'asdf.net:1234', :remote_listen_address => 'ip2.asdf.net:8888').
      instance_eval { @remote_listen_address }.should == 'ip2.asdf.net:8888'
  end

  it "should use localhost for tunnel to address if not specified" do
    Client.new(o :tunnel_to_address => '5555').
      instance_eval { @tunnel_to_address }.should == 'localhost:5555'
  end

end