defmodule MarathonEventExporter.SupervisorTest do
  use ExUnit.Case

  alias MarathonEventExporter.{
    Supervisor, EventCounter, SSEClient, MetricsExporter}

  setup do
    {:ok, fm} = start_supervised(FakeMarathon)
    url = FakeMarathon.base_url(fm) <> "/v2/events"
    {:ok, sup} = start_supervised({Supervisor, {url, 60_000, 0}})
    %{fm: fm, sup: sup}
  end

  def assert_metrics_response(event_counts \\ %{}) do
    url = "http://localhost:#{MetricsExporter.port(MetricsExporter)}/metrics"
    {:ok, response} = HTTPoison.get(url)

    assert response.status_code == 200
    event_counts
      |> Enum.map(fn {e, c} -> ~s'marathon_events_total{event="#{e}"} #{c}' end)
      |> Enum.each(fn metric -> assert response.body =~ metric end)
  end

  test "when events are received the resulting metrics can be queried", %{fm: fm} do
    FakeMarathon.mk_event(fm, "event_stream_attached", remoteAddress: "10.0.0.1")
    FakeMarathon.mk_event(fm, "event_stream_detached", remoteAddress: "10.0.0.1")
    FakeMarathon.mk_event(fm, "event_stream_attached", remoteAddress: "10.0.0.1")

    # Wait for the events to arrive :-/
    Process.sleep(50)

    assert_metrics_response(%{
      "event_stream_attached" => 2,
      "event_stream_detached" => 1,
    })
  end

  test "when the EventCounter exits the client & exporter are restarted" do
    Process.flag(:trap_exit, true)

    # Monitor the client and exporter
    client_ref = Process.whereis(SSEClient) |> Process.monitor()
    exporter_ref = Process.whereis(MetricsExporter) |> Process.monitor()

    # Exit the EventCounter process
    Process.whereis(EventCounter) |> Process.exit(:kill)

    # The client and exporter quit
    assert_receive {:DOWN, ^client_ref, :process, _, :shutdown}, 1_000
    assert_receive {:DOWN, ^exporter_ref, :process, _, :shutdown}, 1_000

    # Wait for the processes to restart :-/
    Process.sleep(50)

    # Things still work as everything has been restarted
    assert_metrics_response()
  end

  test "when the SSE client exits everything else still works", %{fm: fm} do
    Process.flag(:trap_exit, true)

    # Send an event so there is something stored
    FakeMarathon.mk_event(fm, "event_stream_detached", remoteAddress: "10.0.0.1")

    client_ref = Process.whereis(SSEClient) |> Process.monitor()

    # Stop the FakeMarathon so that the client exits
    :ok = stop_supervised(FakeMarathon)

    # Check the client quit
    assert_receive {:DOWN, ^client_ref, :process, _, :normal}, 1_000

    # Everything else still works because it's all still running
    assert_metrics_response(%{"event_stream_detached" => 1})
  end
end
