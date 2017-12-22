defmodule MarathonEventExporter.EventCounterTest do
  use ExUnit.Case, async: true

  alias MarathonEventExporter.EventCounter
  import TestHelpers

  setup do
    {:ok, event_counter} = start_supervised(EventCounter)
    %{ec: event_counter}
  end

  test "no counts returned when no events received", %{ec: ec} do
    assert EventCounter.event_counts(ec) == %{}
  end

  test "counts returned when events received", %{ec: ec} do
    event1 = marathon_event("event_stream_attached", remoteAddress: "10.0.0.1")
    event2 = marathon_event("event_stream_detached", remoteAddress: "10.0.0.1")
    event3 = marathon_event("event_stream_attached", remoteAddress: "10.0.0.1")

    send(ec, {:sse, event1})
    send(ec, {:sse, event2})
    send(ec, {:sse, event3})

    assert EventCounter.event_counts(ec) == %{
      "event_stream_attached" => 2,
      "event_stream_detached" => 1,
    }
  end
end
