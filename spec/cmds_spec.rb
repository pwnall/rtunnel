require File.dirname(__FILE__) + '/spec_helper'

require 'cmds'

include RTunnel

describe RTunnel::CreateConnectionCommand do
  it "should be able to serialize and parse itself" do
    serialized = CreateConnectionCommand.new("id").to_s

    cmd = Command.parse(serialized)
    cmd.class.should == CreateConnectionCommand
    cmd.conn_id.should == "id"
  end

  it "should be able to match itself and remove itself from the stream" do
    serialized = CreateConnectionCommand.new("abcbdefg").to_s

    Command.match(serialized).should == true
    Command.parse(serialized)
    serialized.should be_empty
  end
end

describe RTunnel::SendDataCommand do
  it "should be able to serialzied and parse itself" do
    serialized = SendDataCommand.new("id", "here is some data").to_s

    cmd = Command.parse(serialized)
    cmd.class.should == SendDataCommand
    cmd.conn_id.should == "id"
    cmd.data.should == "here is some data"
  end

  it "should be able to match itself and remove itself from the stream" do
    serialized = SendDataCommand.new("abcbdefg", "and here is some data").to_s

    serialized << "WAY MORE CRAP DATA!!!"

    Command.match(serialized).should == true
    Command.parse(serialized)
    serialized.should == "WAY MORE CRAP DATA!!!"
  end
end

describe RTunnel::CloseConnectionCommand do
  it "should be able to serialize and parse itself" do
    serialized = CloseConnectionCommand.new("id").to_s

    cmd = Command.parse(serialized)
    cmd.class.should == CloseConnectionCommand
    cmd.conn_id.should == "id"
  end

  it "should be able to match itself and remove itself from the stream" do
    serialized = CloseConnectionCommand.new("abcbdefg").to_s

    Command.match(serialized).should == true
    Command.parse(serialized)
    serialized.should be_empty
  end
end

describe RTunnel::PingCommand do
  it "should be able to serialize and parse itself" do
    serialized = PingCommand.new.to_s

    cmd = Command.parse(serialized)
    cmd.class.should == PingCommand
  end

  it "should be able to match itself and remove itself from the stream" do
    serialized = PingCommand.new.to_s

    Command.match(serialized).should == true
    Command.parse(serialized)
    serialized.should be_empty
  end
end


describe RTunnel::RemoteListenCommand do
  it "should be able to serialize and parse itself" do
    serialized = RemoteListenCommand.new("0.0.0.0:1234").to_s

    cmd = Command.parse(serialized)
    cmd.class.should == RemoteListenCommand
    cmd.address.should == "0.0.0.0:1234"
  end

  it "should be able to match itself and remove itself from the stream" do
    serialized = RemoteListenCommand.new("0.0.0.0:1234").to_s

    Command.match(serialized).should == true
    Command.parse(serialized)
    serialized.should be_empty
  end
end


describe RTunnel::Command do
  it "should be able to match a command in a stream" do
    Command.match("C1234abc|").should == true
    Command.match("C1234abc").should == false
    Command.match("C1234abc|C|").should == true

    Command.match("Did|15|DATA").should == false
    Command.match("Did|1|DATA").should == true
    Command.match("Did|4|\0\0\0\0").should == true

    data = "C1234abc|D1234abc|15|here is my dataX1234abc|L0.0.0.0:1234|CASDF"
    cmd1 = Command.parse(data)
    cmd2 = Command.parse(data)
    cmd3 = Command.parse(data)
    cmd4 = Command.parse(data)
    cmd1.class.should == CreateConnectionCommand
    cmd1.conn_id.should == "1234abc"
    cmd2.class.should == SendDataCommand
    cmd2.conn_id.should == "1234abc"
    cmd3.class.should == CloseConnectionCommand
    cmd3.conn_id.should == "1234abc"
    cmd4.class.should == RemoteListenCommand
    cmd4.address.should == "0.0.0.0:1234"

    Command.match(data).should == false
  end
end