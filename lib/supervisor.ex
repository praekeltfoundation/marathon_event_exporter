defmodule MarathonEventExporter.Supervisor do
  @moduledoc """
  The parent Supervisor for the overall program. Supervises the EventCounter
  process as well as the Supervisor for the other processes.
  """

  use Supervisor

  alias MarathonEventExporter.{SSEClient, EventCounter, MetricsExporter}

  @doc """
  Starts a new Supervisor.

  `url` is the URL for the Marathon event stream.
  `timeout` is the timeout value (ms) for the event stream connection.
  `port` is the port that the metrics exporter should listen on.
  """
  def start_link({url, timeout, port}, options \\ []) do
    Supervisor.start_link(__MODULE__, {url, timeout, port}, options)
  end

  defmodule FrontendSupervisor do
    @moduledoc """
    A Supervisor to manage the SSEClient and MetricsExporter which are two
    do not have any dependent processes and so can be restarted independently.
    """
    use Supervisor

    def start_link(arg, options \\ []) do
      Supervisor.start_link(__MODULE__, arg, options)
    end

    def init({event_counter, url, timeout, port}) do
      children = [
        Supervisor.child_spec(SSEClient, start: {
          SSEClient, :start_link,
          [{url, [event_counter], timeout}, [name: SSEClient]]
        }),
        Supervisor.child_spec(MetricsExporter, start: {
          MetricsExporter, :start_link,
          [{port, event_counter}, [name: MetricsExporter]]
        }),
      ]
      Supervisor.init(children, strategy: :one_for_one)
    end
  end

  def init({url, timeout, port}) do
    children = [
      {EventCounter, [name: EventCounter]},
      {FrontendSupervisor, {EventCounter, url, timeout, port}},
    ]
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
