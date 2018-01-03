defmodule MarathonEventExporter.MetricsExporterTest do
  use ExUnit.Case, async: true

  alias MarathonEventExporter.{MetricsExporter, EventCounter}
  import TestHelpers

  setup do
    {:ok, event_counter} = start_supervised(EventCounter)
    {:ok, metrics_exporter} = start_supervised(
      {MetricsExporter, {0, event_counter}})
    %{ec: event_counter, me: metrics_exporter}
  end

  def get_header(response, header_name),
    do: response.headers |> List.keyfind(header_name, 0) |> elem(1)

  test "returns only the metric metadata when no events received", %{me: me} do
    metrics_url = make_metrics_url(me)
    {:ok, response} = HTTPoison.get(metrics_url)

    assert response.status_code == 200
    assert get_header(response, "content-type") == "text/plain; version=0.0.4"
    assert response.body == Enum.join([
      "# HELP marathon_events_total The total number of Marathon events.",
      "# TYPE marathon_events_total counter",
      ""], "\n")
  end

  test "metrics returned when events received", %{me: me, ec: ec} do
    event1 = marathon_event("event_stream_attached", remoteAddress: "10.0.0.1")
    event2 = marathon_event("event_stream_detached", remoteAddress: "10.0.0.1")
    event3 = marathon_event("event_stream_attached", remoteAddress: "10.0.0.1")

    send(ec, {:sse, event1})
    send(ec, {:sse, event2})
    send(ec, {:sse, event3})

    assert_metrics_response(me, %{
      "event_stream_attached" => 2,
      "event_stream_detached" => 1,
    })
  end
end
