require 'rubygems'
require 'eventmachine'

# Event Machine connection that runs a fixed send-expect scenario.
class ScenarioConnection < EventMachine::Connection
  def initialize(test_case, scenario = nil)
    super()

    @test_case = test_case
    @scenario = scenario || yield
    @ignore_unbind = false
    next_step
  end

  def post_init
    scenario_can_send
  end

  def receive_data(data)
    scenario_received data
  end

  def unbind
    return if @ignore_unbind

    unless @step and @step.first == :unbind
      scenario_fail "Received unexpected unbind\n"
    end
    next_step
    while @step and @step.first == :proc
      @step.last.call
      next_step
    end
    if @step and @step.first == :stop
      scenario_stop @step.last
    end
  end

  # Called when data is received. Plays the connection scenario.
  def scenario_received(data)
    unless @step and @step.first == :recv
      scenario_fail "Received unexpected data: #{data}\n"
    end

    @test_case.send :assert_equal, @step.last, data
    next_step
    scenario_can_send
  end

  # Called when data can be sent. Plays the connection scenario.
  def scenario_can_send
    while @step
      case @step.first
      when :proc
        @step.last.call
      when :send
        send_data @step.last
      else
        break
      end
      next_step
    end

    unless @step
      # EM might stifle this exception and reraise
      msg = "Scenario completed prematurely"
      $stderr.puts msg
      fail msg
    end

    case @step.first
    when :receive
      # wait to receive
      return
    when :unbind
      # wait for unbind
      return
    when :close
      @ignore_unbind = true
      close_connection_after_writing
      next_step
    end
  end

  def scenario_fail(fail_message)
    if @step
      fail_message << "Expected to #{@step.inspect}"
    else
      fail_message << "Scenario was completed\n"
    end
    @test_case.send :fail, fail_message
  end

  def scenario_stop(stop_proc)
    if stop_proc.kind_of? Proc
      # call the proc, then give em time to stop all its servers
      stop_proc.call
      EventMachine.add_timer 0.1 do
        EventMachine.stop_event_loop
      end
    else
      EventMachine.stop_event_loop
    end
  end

  def next_step
    @step = @scenario.shift
  end
end