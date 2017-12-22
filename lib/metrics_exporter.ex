defmodule MarathonEventExporter.MetricsExporter do
  @moduledoc """
  A very simple Prometheus event exporter.
  """

  use GenServer

  alias MarathonEventExporter.EventCounter

  defmodule MetricsHandler do
    defp header do
      [
        "# HELP marathon_events_total The total number of Marathon events.",
        "# TYPE marathon_events_total counter",
      ]
    end

    defp metrics(counts) do
      Stream.map(counts, fn
        {event, count} -> ~s'marathon_events_total{event="#{event}"} #{count}'
      end)
    end

    @doc "Converts a mapping of event counts to Prometheus metrics"
    def counts_to_metrics(counts) do
      Stream.concat([header(), metrics(counts), [""]])
      |> Enum.join("\n")
    end

    def init(req, %{event_counter: ec}=state) do
      metrics = EventCounter.event_counts(ec) |> counts_to_metrics
      new_req = :cowboy_req.reply(
        200, %{"content-type" => "text/plain; version=0.0.4"}, metrics, req)
      {:ok, new_req, state}
    end
  end

  defmodule State do
    defstruct port: nil
  end

  def start_link({port, event_counter}, opts \\ []) do
    GenServer.start_link(__MODULE__, {port, event_counter}, opts)
  end

  @doc "Get the port this server is listening on."
  def port(es), do: GenServer.call(es, :port)

  def init({port, event_counter}) do
    # Trap exits so terminate/2 gets called reliably.
    Process.flag(:trap_exit, true)
    handlers = [
      {"/metrics", MetricsHandler, %{event_counter: event_counter}},
    ]
    dispatch = :cowboy_router.compile([{:_, handlers}])
    {:ok, listener} = :cowboy.start_clear(
      :exporter_listener, [port: port], %{env: %{dispatch: dispatch}})
    Process.link(listener)
    {:ok, %State{port: :ranch.get_port(:exporter_listener)}}
  end

  def terminate(reason, _state) do
    :cowboy.stop_listener(:exporter_listener)
    reason
  end

  def handle_call(:port, _from, state), do: {:reply, state.port, state}
end
