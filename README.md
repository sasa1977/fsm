# Fsm

**This project is not maintained anymore, and I don't advise using it. Pure functional FSMs are still my preferred approach (as opposed to gen_statem), but you don't need this library for that. Regular data structures, such as maps or structs, with pattern matching in multiclauses will serve you just fine.**

Fsm is pure functional finite state machine. Unlike `gen_fsm`, it doesn't run in its own process. Instead, it is a functional data structure.

## Why?

In the rare cases I needed a proper fsm, I most often wanted to use it inside the already existing process, together with the already present state data. Creating another process didn't work for me because that requires additional bookkeeping such as supervising and process linking. More importantly, fsm as a process implies mutability and side effects, which is harder to deal with. In addition, `gen_fsm` introduces more complicated protocol of cross-process communication such as `send_event`, `sync_send_event`, `send_all_state_event` and `sync_send_all_state_event`.

Unlike `gen_fsm`, the `Fsm` data structure has following benefits:

* It is immutable and side-effect free
* No need to create and manage separate processes
* You can persist it, use it via ets, embed it inside `gen_server` or plain processes

## Basic example

```elixir
defmodule BasicFsm do
  use Fsm, initial_state: :stopped

  defstate stopped do         # opens the state scope
    defevent run do           # defines event
      next_state(:running)    # transition to next state
    end
  end

  defstate running do
    defevent stop do
      next_state(:stopped)
    end
  end
end
```

Usage:

Be sure to include a dependency in your mix.exs:

```elixir
deps: [{:fsm, "~> 0.3.1"}, ...]
```

```elixir
# basic usage
BasicFsm.new
|> BasicFsm.run
|> BasicFsm.stop

# invalid state/event combination throws exception
BasicFsm.new
|> BasicFsm.run
|> BasicFsm.run

# you can query fsm for its state:
BasicFsm.new
|> BasicFsm.run
|> BasicFsm.state
```

## Data
As you probably know, basic fsm is not Turing complete, and has limited uses. Therefore, `Fsm` introduces concept of data, just like `gen_fsm`:

```elixir
defmodule DataFsm do
  use Fsm, initial_state: :stopped, initial_data: 0

  defstate stopped do
    defevent run(speed) do                    # events can have arguments
      next_state(:running, speed)             # changing state and data
    end
  end

  defstate running do
    defevent slowdown(by), data: speed do     # you can pattern match data with dedicated option
      next_state(:running, speed - by)
    end

    defevent stop do
      next_state(:stopped, 0)
    end
  end
end

DataFsm.new
|> DataFsm.run(50)
|> DataFsm.slowdown(10)
|> DataFsm.data
```

## Global handlers

Normally, undefined state/event mapping throws an exception. You can handle this by using special `_` event definition:

```elixir
defmodule BasicFsm do
  use Fsm, initial_state: :stopped

  defstate stopped do
    defevent run, do: next_state(:running)

    # called for undefined state/event mapping when inside stopped state
    defevent _, do:
  end

  defstate running do
    defevent stop, do: next_state(:stopped)
  end

  # called for some_event, regardless of the state
  defevent some_event, do:

  # called for undefined state/event mapping when inside any state
  defevent _, do:
end
```

Keep in mind that public functions are defined only for the specified events. In the example above those are `run`, `stop`, and `some_event`. So you cannot call `BasicFsm.undefined_event`, because such event is not defined. You can explicitly define events, without adding them to state/event map:

```elixir
defmodule MyFsm do
  defevent my_event1        # 0 arity event
  defevent my_event2/2      # 2 arity event
end
```

In global handlers, it is often useful to know about event context:

```elixir
defevent _, state: state, data: data, event: event, args: args do
  # now you can reference state, data, event and args
  ...
end
```

## Pattern matching and options

Pattern matching works with event arguments, and all available options:

```elixir
defstate some_state do
  defevent event(1), do:
  defevent event(2), do:

  defevent event(x), state: 0, do:
  defevent event(x), state: 1, do:
end
```

It is allowed to define multiple global handlers:

```elixir
defevent _, event: :event_1, do:
defevent _, event: :event_2, do:
defevent _, event: something_else, do:
```

You can also specify guards:
```elixir
defevent my_event, when: ..., do:
```

## Event results
The result of the event handler determines the response of the event:

```elixir
defevent my_event do
  ...
  next_state(:new_state)             # data remains the same
end

defevent my_event do
  ...
  next_state(:new_state, new_data)
end
```

The result of the event will be the new fsm instance:

```elixir
fsm2 = MyFsm.my_event(fsm)
MyFsm.another_event(fsm2, ...)
```

You can also return some result and the modified fsm instance:
```elixir
respond(response)                         # data and state remain the same
respond(response, :new_state)             # data remains the same
respond(response, :new_state, new_data)
```

In this case, the result of calling the event is a two elements tuple:
```elixir
{response, fsm2} = MyFsm.my_event(mfs)
```

If the result of event handler is not created via `next_state` or `respond` it will be ignored, and the input fsm instance will be returned. This is useful when the event handler needs to perform some side-effect operations (file or network I/O) without changing the state or data.

## Dynamic definitions
Fsm macros are runtime friendly, so you can build your fsm dynamically:

```elixir
defmodule DynamicFsm do
  use Fsm, initial_state: :stopped

  # define states and transition
  fsm = [
    stopped: [run: :running],
    running: [stop: :stopped]
  ]

  # loop through definition and dynamically call defstate/defevent
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
```

You might use this to define your fsm in the separate file, and in compile time read it and build the corresponding module.

## Generated functions
Normally, `defevent` generates corresponding public interface function, which has the same name as the event. In addition, the multi-clause public `transition` function exists where all possible transitions are implemented. Interface functions simply delegate to the `transition` function, and their purpose is simply to have nicer looking interface.

You can make interface function private:

```elixir
defeventp ...
```

The `transition` function is always public. It can be used for dynamic fsm manipulation:

```elixir
MyFsm.transition(fsm, :my_event, [arg1, arg2])
```

Notice that with `transition`, you can also use undefined events, and they will be caught by global handlers (if such exist).

## Extending the module
Inside your fsm module, you can add additional functions which manipulate the fsm. An fsm instance is represented by the private `fsm_rec` record:

```elixir
def my_fun(fsm_rec() = fsm, ...), do:
```

## In a separate process
Fsm makes sense even when used from a separate process. Instead of relying on `gen_fsm` verbs, you can use `gen_server` simple call/cast approach. If the interface of the fsm is large, it may be tedious to create wrappers for all events. Runtime friendly [ExActor](https://github.com/sasa1977/exactor) can make your life a bit easier:

```elixir
defmodule BasicFsmServer do
  use ExActor

  def init(_), do: initial_state(BasicFsm.new)

  # dynamic wrapping of zero arity events inside casts
  for event <- [:run, :stop] do
    defcast unquote(event), state: fsm do
      BasicFsm.unquote(event)(fsm)
      |> new_state
    end
  end

  # call wrapper to get the state
  defcall state, state: fsm, do: BasicFsm.state(fsm)
end
```
