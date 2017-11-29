defmodule MarathonEventExporter.SSEParser do
  @moduledoc """
  A GenServer to turn a stream of bytes (usually from an HTTP response) into a
  stream of server-sent events.

  See https://html.spec.whatwg.org/multipage/server-sent-events.html
  (particularly sections 9.2.4 and 9.2.5) for the protocol specification.
  """

  use GenServer

  defmodule Event do
    defstruct data: "", event: "", id: ""
  end

  defmodule State do
    defstruct listeners: MapSet.new, event: %Event{}, line_part: ""
  end


  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def feed_data(server, data) do
    GenServer.cast(server, {:feed_data, data})
  end

  def register_listener(server, pid) do
    GenServer.call(server, {:register_listener, pid})
  end

  def unregister_listener(server, pid) do
    GenServer.call(server, {:unregister_listener, pid})
  end


  ## Server callbacks

  def init(:ok) do
    {:ok, %State{}}
  end

  def handle_cast({:feed_data, data}, state) do
    new_state = data_received(data, state)
    {:noreply, new_state}
  end

  def handle_call({:register_listener, pid}, _from, state) do
    new_listeners = MapSet.put(state.listeners, pid)
    {:reply, :ok, %{state | listeners: new_listeners}}
  end

  def handle_call({:unregister_listener, pid}, _from, state) do
    new_listeners = MapSet.delete(state.listeners, pid)
    {:reply, :ok, %{state | listeners: new_listeners}}
  end

  def handle_call(:_get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end


  ## Internals

  def emit_event(state) do
    IO.puts("event: #{inspect state.event}")
    %{state | event: %Event{}}
  end


  ## Parser

  # This clause handles the end of the input.
  defp data_received("", state) do
    state
  end
  # These three clauses handle newlines.
  defp data_received("\r\n" <> data, state), do: line_complete(data, state)
  defp data_received("\r" <> data, state), do: line_complete(data, state)
  defp data_received("\n" <> data, state), do: line_complete(data, state)
  # This clause handles anything not matche above, which is all non-newlines
  # characters.
  defp data_received(<<char, data :: binary>>, state) do
    %State{line_part: line} = state
    new_state = %{state | line_part: line <> <<char>>}
    data_received(data, new_state)
  end

  defp line_complete(data, state) do
    new_state = line_received(state.line, %{state | line_part: ""})
    data_received(data, new_state)
  end

  defp line_received(line, state) do
    IO.puts("line: #{line}")
    state
  end

end
