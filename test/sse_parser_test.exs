defmodule MarathonEventExporter.SSEParserTest do
  use ExUnit.Case, async: true

  alias MarathonEventExporter.SSEParser
  alias SSEParser.{Event, State}

  setup do
    {:ok, ssep} = start_supervised SSEParser
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

  test "feed_data", %{ssep: ssep} do
    assert SSEParser.feed_data(ssep, "hello") == :ok
    assert SSEParser.feed_data(ssep, " ") == :ok
    assert SSEParser.feed_data(ssep, "world") == :ok
    assert get_state(ssep) == %State{event: %Event{}, line_part: "hello world"}
  end

end
