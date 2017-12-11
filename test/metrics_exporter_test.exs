defmodule MarathonEventExporter.MetricsExporterTest do
  use ExUnit.Case, async: true

  alias MarathonEventExporter.MetricsExporter
  alias MetricsExporter.MetricsAgent
  import TestHelpers

  setup do
    {:ok, metrics_agent} = start_supervised(MetricsAgent)
    {:ok, metrics_exporter} = start_supervised(
      {MetricsExporter, {0, metrics_agent}})
    %{me: metrics_exporter}
  end

  def get_header(response, header_name),
    do: response.headers |> List.keyfind(header_name, 0) |> elem(1)

  def make_metrics_url(me),
    do: "http://localhost:#{MetricsExporter.port(me)}/metrics"

  test "metrics endpoint returns Prometheus metrics", %{me: me} do
    metrics_url = make_metrics_url(me)
    {:ok, response} = HTTPoison.get(metrics_url)

    assert response.status_code == 200
    assert get_header(response, "content-type") == "text/plain; version=0.0.4"
    assert response.body == Enum.join([
      "# HELP marathon_events_total The total number of Marathon events.",
      "# TYPE marathon_events_total counter",
      ""], "\n")

    event = marathon_event("event_stream_attached", remoteAddress: "127.0.0.1")
    send(me, {:sse, event})

    {:ok, response2} = HTTPoison.get(metrics_url)
    assert response2.status_code == 200
    assert response2.body == Enum.join([
      "# HELP marathon_events_total The total number of Marathon events.",
      "# TYPE marathon_events_total counter",
      ~s'marathon_events_total{event="event_stream_attached"} 1',
      ""], "\n")
  end

end
