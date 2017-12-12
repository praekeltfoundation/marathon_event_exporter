defmodule MarathonEventExporter.MarathonClientTest do
  use ExUnit.Case, async: true

  alias MarathonEventExporter.MarathonClient
  import TestHelpers

  test "stream_events streams events to a listener process" do
    {:ok, fm} = start_supervised(FakeMarathon)
    base_url = FakeMarathon.base_url(fm)
    {:ok, _} = MarathonClient.stream_events(base_url, [self()])
    # FIXME: stream_events returns as soon as the request has been sent, which
    # means the server may not have received it yet. This creates a race
    # between the stream setup and the first event, so until that's fixed we'll
    # just wait a few milliseconds here.
    Process.sleep(65)

    # Stream an event, assert that we receive it within a second.
    event = marathon_event("event_stream_attached", remoteAddress: "127.0.0.1")
    FakeMarathon.event(fm, event.event, event.data)
    assert_receive {:sse, ^event}, 1_000

    # Stream and assert on another event.
    event2 = marathon_event("event_stream_attached", remoteAddress: "10.1.2.3")
    FakeMarathon.event(fm, event2.event, event2.data)
    assert_receive {:sse, ^event2}, 1_000
  end

  test "stream_events exits when the server connection is closed" do
    {:ok, fm} = start_supervised(FakeMarathon)
    base_url = FakeMarathon.base_url(fm)
    {:ok, se} = MarathonClient.stream_events(base_url, [self()])
    ref = Process.monitor(se)
    # FIXME: stream_events returns as soon as the request has been sent, which
    # means the server may not have received it yet. This creates a race
    # between the stream setup and the first event, so until that's fixed we'll
    # just wait a few milliseconds here.
    Process.sleep(65)

    # Stream an event, assert that we receive it within a second.
    event = marathon_event("event_stream_attached", remoteAddress: "127.0.0.1")
    FakeMarathon.event(fm, event.event, event.data)
    assert_receive {:sse, ^event}, 1_000

    # Close the connection on the server side.
    FakeMarathon.end_stream(fm)
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 1_000
  end
end
