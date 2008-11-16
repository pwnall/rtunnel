require 'rubygems'
require 'eventmachine'

# Event Machine connection that runs a fixed send-expect scenario.
class ScenarioConnection < EventMachine::Connection
  def initialize(test_case, scenario = nil)
    super()
    
    @test_case = test_case
    @scenario = scenario || yield
    @step = 0
    @ignore_unbind = false
  end
  
  def post_init
    scenario_can_send
  end
  
  def receive_data(data)
    scenario_received data
  end

  def unbind
    return if @ignore_unbind
    
    unless @step < @scenario.length and @scenario[@step].first == :unbind
      scenario_fail "Received unexpected unbind\n"      
    end
    @step += 1
    if @step < @scenario.length and @scenario[@step].first == :stop
      EventMachine::stop_event_loop
    end
  end

  # Called when data is received. Plays the connection scenario.
  def scenario_received(data)
    unless @step < @scenario.length and @scenario[@step].first == :recv
      scenario_fail "Received unexpected data: #{data}\n"
    end
    
    @test_case.send :assert_equal, @scenario[@step].last, data
    @step += 1
    scenario_can_send
  end
  
  # Called when data can be sent. Plays the connection scenario.
  def scenario_can_send
    while @step < @scenario.length
      case @scenario[@step].first
      when :proc
        proc.call
      when :send
        send_data @scenario[@step].last        
      else
        break
      end
      @step += 1
    end
    
    unless @step < @scenario.length
      @test_case.send :fail, "Scenario completed prematurely\n"
    end

    case @scenario[@step].first
    when :receive
      # wait to receive
      return
    when :unbind
      # wait for unbind
      return
    when :close
      @ignore_unbind = true
      close_connection_after_writing
      @step += 1
    end
  end
    
  def scenario_fail(fail_message)
    if @step < @scenario.length
      fail_message << "Expected to #{@scenario[@step].inspect}"
    else
      fail_message << "Scenario was completed\n"
    end
    @test_case.send :fail, fail_message
  end
end