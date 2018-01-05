defmodule MarathonEventExporterTest do
  use ExUnit.Case


  alias MarathonEventExporter.MetricsExporter

  setup do
    {:ok, fm} = start_supervised(FakeMarathon)
    url = FakeMarathon.base_url(fm) <> "/v2/events"
    set_app_config(:marathon_url, url)
    %{fm: fm, url: url}
  end

  def set_app_config(key, value) do
    old_value = Application.fetch_env!(:marathon_event_exporter, key)
    on_exit(fn -> Application.put_env(:marathon_event_exporter, key, old_value) end)
    Application.put_env(:marathon_event_exporter, key, value)
  end

  def assert_metrics_response(event_counts \\ %{}) do
    url = "http://localhost:#{MetricsExporter.port(MetricsExporter)}/metrics"
    {:ok, response} = HTTPoison.get(url)

    assert response.status_code == 200
    event_counts
    |> Enum.map(fn {e, c} -> ~s'marathon_events_total{event="#{e}"} #{c}' end)
    |> Enum.each(fn metric -> assert response.body =~ metric end)
  end

  @tag :application
  test "the application publishes event metrics", %{fm: fm} do
    Application.start(:marathon_event_exporter)
    on_exit(fn -> Application.stop(:marathon_event_exporter) end)

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
end
