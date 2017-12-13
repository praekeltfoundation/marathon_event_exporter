defmodule MarathonEventExporter.MarathonClientTest do
  use ExUnit.Case, async: true

  alias MarathonEventExporter.MarathonClient
  import TestHelpers

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

  test "stream_events exits when the server connection is closed" do
    {:ok, fm} = start_supervised(FakeMarathon)
    base_url = FakeMarathon.base_url(fm)
    {:ok, se} = MarathonClient.stream_events(base_url, [self()])
    ref = Process.monitor(se)

    # Stream an event, assert that we receive it within a second.
    event = marathon_event("event_stream_attached", remoteAddress: "127.0.0.1")
    FakeMarathon.event(fm, event.event, event.data)
    assert_receive {:sse, ^event}, 1_000

    # Close the connection on the server side.
    FakeMarathon.end_stream(fm)
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 1_000
  end

  test "stream_events fails on a bad response" do
    # Trap exits so the start_link in stream_events doesn't break the test.
    Process.flag(:trap_exit, true)
    {:ok, fm} = start_supervised(FakeMarathon)
    base_url = FakeMarathon.base_url(fm)
    {:error, err} =  MarathonClient.stream_events(base_url <> "/bad", [self()])
    assert err =~ ~r/Error connecting to event stream: .*{code: 404/
  end

  test "stream_events only returns once a response is received" do
    # On my machine, without waiting for the response, the delay is
    # consistently under 100ms. I chose 250ms here as a balance between
    # incorrect results and waiting too long.
    delay_ms = 250

    {:ok, fm} = start_supervised({FakeMarathon, [response_delay: delay_ms]})
    base_url = FakeMarathon.base_url(fm)
    t0 = Time.utc_now()
    {:ok, _} = MarathonClient.stream_events(base_url, [self()])
    t1 = Time.utc_now()
    assert Time.diff(t1, t0, :milliseconds) >= delay_ms

    # Stream an event, assert that we receive it within a second.
    event = marathon_event("event_stream_attached", remoteAddress: "127.0.0.1")
    FakeMarathon.event(fm, event.event, event.data)
    assert_receive {:sse, ^event}, 1_000
  end
end
