defmodule FsmTest do
  use ExUnit.Case

  defmodule BasicFsm do
    use Fsm, initial_state: :stopped

    defstate stopped do
      defevent run do
        next_state(:running)
      end
    end

    defstate running do
      defevent stop do
        next_state(:stopped)
      end
    end
  end

  test "basic" do
    assert(
      BasicFsm.new
      |> BasicFsm.state == :stopped)

    assert(
      BasicFsm.new
      |> BasicFsm.run
      |> BasicFsm.state == :running)

    assert(
      BasicFsm.new
      |> BasicFsm.run
      |> BasicFsm.stop
      |> BasicFsm.state == :stopped)

    assert_raise(FunctionClauseError, fn ->
      BasicFsm.new
      |> BasicFsm.run
      |> BasicFsm.run
    end)
  end



  defmodule PrivateFsm do
    use Fsm, initial_state: :stopped

    defstate stopped do
      defeventp run do
        next_state(:running)
      end
    end

    def my_run(fsm), do: run(fsm)
  end

  test "private" do
    assert_raise(UndefinedFunctionError, fn ->
      PrivateFsm.new
      |> PrivateFsm.run
    end)

    assert(
      PrivateFsm.new
      |> PrivateFsm.my_run
      |> PrivateFsm.state == :running
    )
  end



  defmodule GlobalHandlers do
    use Fsm, initial_state: :stopped

    defstate stopped do
      defevent undefined_event1
      defevent undefined_event2/2

      defevent run do
        next_state(:running)
      end

      defevent _ do
        next_state(:invalid1)
      end
    end

    defstate running do
      defevent stop do
        next_state(:stopped)
      end
    end

    defevent _ do
      next_state(:invalid2)
    end
  end

  test "global handlers" do
    assert(
      GlobalHandlers.new
      |> GlobalHandlers.undefined_event1
      |> GlobalHandlers.state == :invalid1
    )

    assert(
      GlobalHandlers.new
      |> GlobalHandlers.run
      |> GlobalHandlers.undefined_event2(1,2)
      |> GlobalHandlers.state == :invalid2
    )
  end



  defmodule DataFsm do
    use Fsm, initial_state: :stopped, initial_data: 0

    defstate stopped do
      defevent run(speed) do
        next_state(:running, speed)
      end
    end

    defstate running do
      defevent slowdown(by), data: speed do
        next_state(:running, speed - by)
      end

      defevent stop do
        next_state(:stopped, 0)
      end
    end
  end

  test "data" do
    assert(
      DataFsm.new
      |> DataFsm.data == 0
    )

    assert(
      DataFsm.new
      |> DataFsm.run(50)
      |> DataFsm.data == 50
    )

    assert(
      DataFsm.new
      |> DataFsm.run(50)
      |> DataFsm.slowdown(20)
      |> DataFsm.data == 30
    )

    assert(
      DataFsm.new
      |> DataFsm.run(50)
      |> DataFsm.stop
      |> DataFsm.data == 0
    )
  end



  defmodule ResponseFsm do
    use Fsm, initial_state: :stopped, initial_data: 0

    defstate stopped do
      defevent run(speed) do
        respond(:ok, :running, speed)
      end

      defevent _ do
        respond(:error)
      end
    end

    defstate running do
      defevent stop do
        respond(:ok, :stopped, 0)
      end

      defevent _ do
        respond(:error, :invalid)
      end
    end
  end

  test "response actions" do
    {response, fsm} = ResponseFsm.new
    |> ResponseFsm.run(50)

    assert(response == :ok)
    assert(ResponseFsm.state(fsm) == :running)
    assert(ResponseFsm.data(fsm) == 50)

    {response2, fsm2} = ResponseFsm.run(fsm, 10)
    assert(response2 == :error)
    assert(ResponseFsm.state(fsm2) == :invalid)

    assert(
      ResponseFsm.new
      |> ResponseFsm.stop == {:error, %ResponseFsm{data: 0, state: :stopped}}
    )
  end



  defmodule PatternMatch do
    use Fsm, initial_state: :running, initial_data: 10

    defstate running do
      defevent toggle_speed, data: d, when: d == 10 do
        next_state(:running, 50)
      end

      defevent toggle_speed, data: 50 do
        next_state(:running, 10)
      end

      defevent set_speed(1) do
        next_state(:running, 10)
      end

      defevent set_speed(x), when: x == 2 do
        next_state(:running, 50)
      end

      defevent stop, do: next_state(:stopped)
    end

    defevent dummy, state: :stopped do
      respond(:dummy)
    end

    defevent _, event: :toggle_speed do
      respond(:error)
    end
  end

  test "pattern match" do
    assert(
      PatternMatch.new
      |> PatternMatch.toggle_speed
      |> PatternMatch.data == 50
    )

    assert(
      PatternMatch.new
      |> PatternMatch.toggle_speed
      |> PatternMatch.toggle_speed
      |> PatternMatch.data == 10
    )

    assert(
      PatternMatch.new
      |> PatternMatch.set_speed(1)
      |> PatternMatch.data == 10
    )

    assert(
      PatternMatch.new
      |> PatternMatch.set_speed(2)
      |> PatternMatch.data == 50
    )

    assert_raise(FunctionClauseError, fn ->
      PatternMatch.new
      |> PatternMatch.set_speed(3)
      |> PatternMatch.data == 50
    end)

    assert(
      PatternMatch.new
      |> PatternMatch.stop
      |> PatternMatch.dummy == {:dummy, %PatternMatch{data: 10, state: :stopped}}
    )

    assert(
      PatternMatch.new
      |> PatternMatch.stop
      |> PatternMatch.toggle_speed == {:error, %PatternMatch{data: 10, state: :stopped}}
    )

    assert_raise(FunctionClauseError, fn ->
      PatternMatch.new
      |> PatternMatch.dummy
    end)

    assert_raise(FunctionClauseError, fn ->
      PatternMatch.new
      |> PatternMatch.stop
      |> PatternMatch.stop
    end)

    assert_raise(FunctionClauseError, fn ->
      PatternMatch.new
      |> PatternMatch.stop
      |> PatternMatch.set_speed(1)
    end)
  end



  defmodule DynamicFsm do
    use Fsm, initial_state: :stopped

    fsm = [
      stopped: [run: :running],
      running: [stop: :stopped]
    ]

    for {state, transitions} <- fsm do
      defstate unquote(state) do
        for {event, target_state} <- transitions do
          defevent unquote(event) do
            next_state(unquote(target_state))
          end
        end
      end
    end
  end

  test "dynamic" do
    assert(
      DynamicFsm.new
      |> DynamicFsm.state == :stopped)

    assert(
      DynamicFsm.new
      |> DynamicFsm.run
      |> DynamicFsm.state == :running)

    assert(
      DynamicFsm.new
      |> DynamicFsm.run
      |> DynamicFsm.stop
      |> DynamicFsm.state == :stopped)

    assert_raise(FunctionClauseError, fn ->
      DynamicFsm.new
      |> DynamicFsm.run
      |> DynamicFsm.run
    end)
  end
end
