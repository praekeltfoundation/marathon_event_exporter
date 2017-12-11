defmodule MarathonEventExporter.MetricsExporter do
  @moduledoc """
  A very simple Prometheus event exporter.
  """

  use GenServer

  defmodule MetricsAgent do
    @moduledoc """
    Agent to keep a mapping of event type to the number of times that event has
    occurred.
    """
    use Agent

    def start_link(_) do
      Agent.start_link(fn -> %{} end, name: __MODULE__)
    end

    @doc """
    Increment the count of the number of times an event type has occurred.
    """
    def increment_event(ma, event) do
      Agent.update(ma, fn state -> Map.update(state, event, 1, &(&1 + 1)) end)
    end

    @doc "Get the mapping of all event types to counts."
    def get_events(ma) do
      Agent.get(ma, fn state -> state end)
    end
  end

  defmodule MetricsHandler do
    defp events_header do
      [
        "# HELP marathon_events_total The total number of Marathon events.",
        "# TYPE marathon_events_total counter",
      ]
    end

    defp events_metrics(events) do
      Stream.map(events, fn
        {event, count} -> ~s'marathon_events_total{event="#{event}"} #{count}'
      end)
    end

    @doc "Converts a mapping of event counts to Prometheus metrics"
    def events_to_metrics(events) do
      Stream.concat([events_header(), events_metrics(events), [""]])
      |> Enum.join("\n")
    end

    def init(req, %{metrics_agent: metrics_agent}=state) do
      metrics = MetricsAgent.get_events(metrics_agent) |> events_to_metrics
      new_req = :cowboy_req.reply(
        200, %{"content-type" => "text/plain; version=0.0.4"}, metrics, req)
      {:ok, new_req, state}
    end
  end

  defmodule State do
    defstruct port: nil, metrics_agent: nil
  end

  def start_link({port, metrics_agent}) do
    GenServer.start_link(
      __MODULE__, {port, metrics_agent}, name: :exporter_server)
  end

  @doc "Get the port this server is listening on."
  def port(es), do: GenServer.call(es, :port)

  @doc "Get the pid for the MetricsAgent this server uses."
  def metrics_agent(es), do: GenServer.call(es, :metrics_agent)

  def init({port, metrics_agent}) do
    handlers = [
      {"/metrics", MetricsHandler, %{metrics_agent: metrics_agent}},
    ]
    dispatch = :cowboy_router.compile([{:_, handlers}])
    {:ok, listener} = :cowboy.start_clear(
      :exporter_listener, [port: port], %{env: %{dispatch: dispatch}})
    Process.link(listener)
    {:ok, %State{
      port: :ranch.get_port(:exporter_listener),
      metrics_agent: metrics_agent
    }}
  end

  def handle_call(:port, _from, state), do: {:reply, state.port, state}
  def handle_call(:metrics_agent, _from, state) do
    {:reply, state.metrics_agent, state}
  end
end
