defmodule Fsm do
  defmacro __using__(opts) do
    quote do
      import Fsm

      defrecordp :fsm_rec, __MODULE__, [:state, :data]

      state = nil
      declared_events = HashSet.new

      def new do
        fsm_rec(state: unquote(opts[:initial_state]), data: unquote(opts[:initial_data]))
      end

      def state(fsm_rec(state: state)), do: state
      def data(fsm_rec(data: data)), do: data

      defp change_state(fsm_rec() = fsm, {:action_responses, responses}), do: parse_action_responses(fsm, responses)
      defp change_state(fsm_rec() = fsm, _), do: fsm

      defp parse_action_responses(fsm, responses) do
        Enum.reduce(responses, fsm, fn(response, fsm) ->
          handle_action_response(fsm, response)
        end)
      end

      defp handle_action_response(fsm_rec() = fsm, {:next_state, next_state}) do
        fsm_rec(fsm, state: next_state)
      end

      defp handle_action_response(fsm_rec() = fsm, {:new_data, new_data}) do
        fsm_rec(fsm, data: new_data)
      end

      defp handle_action_response(fsm_rec() = fsm, {:respond, response}) do
        {response, fsm}
      end
    end
  end

  def next_state(state), do: {:action_responses, [next_state: state]}
  def next_state(state, data), do: {:action_responses, [next_state: state, new_data: data]}

  def respond(response), do: {:action_responses, [respond: response]}
  def respond(response, state), do: {:action_responses, [next_state: state, respond: response]}
  def respond(response, state, data), do: {:action_responses, [next_state: state, new_data: data, respond: response]}

  defmacro defstate(state, state_def) do
    quote do
      state_name = case unquote(Macro.escape(state, unquote: true)) do
        name when is_atom(name) -> name
        {name, _, _} -> name
      end

      state = state_name
      unquote(state_def)
      state = nil
    end
  end

  defmacro defevent(event) do
    decl_event(event, false)
  end

  defmacro defeventp(event) do
    decl_event(event, true)
  end

  defp decl_event(event, private) do
    quote do
      {event_name, arity} = case unquote(Macro.escape(event, unquote: nil)) do
        event_name when is_atom(event_name) -> {event_name, 0}
        {:/, _, [{event_name, _, _}, arity]} -> {event_name, arity}
        {event_name, _, _} -> {event_name, 0}
      end

      args = case arity do
        0 -> []
        n -> Enum.to_list(1..n)
      end

      private = unquote(private)
      unquote(define_interface)
    end
  end

  defmacro defevent(event, opts) do
    do_defevent(event, opts, opts[:do])
  end

  defmacro defevent(event, opts, do: event_def) do
    do_defevent(event, opts, event_def)
  end

  defmacro defeventp(event, opts) do
    do_defevent(event, [{:private, true} | opts], opts[:do])
  end

  defmacro defeventp(event, opts, do: event_def) do
    do_defevent(event, [{:private, true} | opts], event_def)
  end

  defp do_defevent(event_decl, opts, event_def) do
    quote do
      unquote(extract_args(event_decl, opts, event_def))
      unquote(define_interface)
      unquote(implement_transition)
    end
  end

  defp extract_args(event_decl, opts, event_def) do
    quote do
      {event_name, args} = case unquote(Macro.escape(event_decl, unquote: true)) do
        :_ -> {:_, []}
        name when is_atom(name) -> {name, []}
        {name, _, args} -> {name, args || []}
      end

      private = unquote(opts[:private])
      state_arg = unquote(Macro.escape(opts[:state] || quote(do: _), unquote: true))
      data_arg = unquote(Macro.escape(opts[:data] || quote(do: _), unquote: true))
      event_arg = unquote(Macro.escape(opts[:event] || quote(do: _), unquote: true))
      args_arg = unquote(Macro.escape(opts[:args] || quote(do: _), unquote: true))
      event_def = unquote(Macro.escape(event_def, unquote: true))
      guard = unquote(Macro.escape(opts[:when]))
      if guard, do: guard = [guard], else: guard = []
    end
  end

  defp define_interface do
    quote do
      unless event_name == :_ or HashSet.member?(declared_events, {event_name, length(args)}) do
        interface_args = Enum.reduce(args, {0, []}, fn(_, {index, args}) ->
          {
            index + 1,
            [{:"arg#{index}", [], nil} | args]
          }
        end)
        |> elem(1)
        |> Enum.reverse

        body = [do: quote do
          transition(fsm, unquote(event_name), [unquote_splicing(interface_args)])
        end]

        interface_args = [quote(do: fsm) | interface_args]

        definer = if private, do: &defp/4, else: &def/4
        apply(definer, [event_name, interface_args, [], body])

        declared_events = HashSet.put(declared_events, {event_name, length(args)})
      end
    end
  end

  defp implement_transition do
    quote do
      transition_args = [
        if state do
          quote do
            fsm_rec(state: unquote(state) = unquote(state_arg), data: unquote(data_arg)) = fsm
          end
        else
          quote do
            fsm_rec(state: unquote(state_arg), data: unquote(data_arg)) = fsm
          end
        end,

        quote do
          unquote(if event_name == :_, do: quote(do: _), else: event_name) = unquote(event_arg)
        end,

        quote do
          unquote(if event_name == :_, do: quote(do: _), else: args) = unquote(args_arg)
        end
      ]

      def(
        :transition,
        transition_args,
        guard,
        do: quote do
          change_state(fsm, (unquote(event_def)))
        end
      )
    end
  end
end