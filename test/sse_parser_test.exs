defmodule MarathonEventExporter.SSEParserTest do
  use ExUnit.Case, async: true

  alias MarathonEventExporter.SSEParser
  alias SSEParser.{Event, State}

  defmodule EventCatcher do
    use GenServer

    def start_link(opts), do: GenServer.start_link(__MODULE__, [], opts)
    def events(server), do: GenServer.call(server, :events)

    def handle_call(:events, _from, events), do: {:reply, events, events}
    def handle_info({:sse, event}, events), do: {:noreply, [event | events]}
  end

  setup do
    {:ok, ssep} = start_supervised(SSEParser)
    %{ssep: ssep}
  end

  def get_state(ssep) do
    {:ok, state} = GenServer.call(ssep, :_get_state)
    state
  end

  test "register_listener is idempotent", %{ssep: ssep} do
    assert get_state(ssep) == %State{listeners: MapSet.new()}
    assert SSEParser.register_listener(ssep, self()) == :ok
    assert get_state(ssep) == %State{listeners: MapSet.new([self()])}
    assert SSEParser.register_listener(ssep, self()) == :ok
    assert get_state(ssep) == %State{listeners: MapSet.new([self()])}
  end

  test "unregister_listener is idempotent", %{ssep: ssep} do
    assert SSEParser.register_listener(ssep, self()) == :ok
    assert get_state(ssep) == %State{listeners: MapSet.new([self()])}
    assert SSEParser.unregister_listener(ssep, self()) == :ok
    assert get_state(ssep) == %State{listeners: MapSet.new()}
    assert SSEParser.unregister_listener(ssep, self()) == :ok
    assert get_state(ssep) == %State{listeners: MapSet.new()}
  end

  test "a listener receives events", %{ssep: ssep} do
    {:ok, listener} = start_supervised(EventCatcher)
    assert SSEParser.register_listener(ssep, listener) == :ok
    assert EventCatcher.events(listener) == []
    assert SSEParser.feed_data(ssep, "data: hello\n\n") == :ok
    assert get_state(ssep).event == %Event{}
    assert EventCatcher.events(listener) == [%Event{data: "hello"}]
  end

  test "multiple listeners receive events", %{ssep: ssep} do
    {:ok, l1} = start_supervised(EventCatcher, id: :l1)
    {:ok, l2} = start_supervised(EventCatcher, id: :l2)
    assert SSEParser.register_listener(ssep, l1) == :ok
    assert SSEParser.register_listener(ssep, l2) == :ok
    assert SSEParser.feed_data(ssep, "data: sanibonani\n\n") == :ok
    assert get_state(ssep).event == %Event{}
    assert EventCatcher.events(l1) == [%Event{data: "sanibonani"}]
    assert EventCatcher.events(l2) == [%Event{data: "sanibonani"}]
  end

  test "feed_data", %{ssep: ssep} do
    assert SSEParser.feed_data(ssep, "hello") == :ok
    assert SSEParser.feed_data(ssep, " ") == :ok
    assert SSEParser.feed_data(ssep, "world") == :ok
    assert get_state(ssep) == %State{event: %Event{}, line_part: "hello world"}
  end

end
