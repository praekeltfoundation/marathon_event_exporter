defmodule MarathonEventExporter.MarathonClientTest do
  use ExUnit.Case, async: true

  alias MarathonEventExporter.{MarathonClient, SSEParser}

  @doc """
  Build a Marathon event from the given type and fields.

  The :eventType field is always added/overridden, the :timestamp field is
  added if one is not provided.
  """
  def marathon_event(event_type, fields) do
    {:ok, data} = Map.new(fields)
    |> Map.put_new(:timestamp, DateTime.utc_now |> DateTime.to_iso8601)
    |> Map.put(:eventType, event_type)
    |> JSX.encode
    %SSEParser.Event{event: event_type, data: data}
  end

  test "stream_events streams events to a listener process" do
    {:ok, fm} = start_supervised(FakeMarathon)
    base_url = FakeMarathon.base_url(fm)
    {:ok, _} = MarathonClient.stream_events(base_url, [self()])
    # Stream an event, assert that we receive it within a second.
    event = marathon_event("event_stream_attached", remoteAddress: "127.0.0.1")
    FakeMarathon.event(fm, event.event, event.data)
    assert_receive {:sse, ^event}, 1_000
    # Stream and assert on another event.
    event2 = marathon_event("event_stream_attached", remoteAddress: "10.1.2.3")
    FakeMarathon.event(fm, event2.event, event2.data)
    assert_receive {:sse, ^event2}, 1_000
  end
end
