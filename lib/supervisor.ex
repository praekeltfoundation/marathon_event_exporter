defmodule MarathonEventExporter.Supervisor do
  use Supervisor

  alias MarathonEventExporter.{SSEClient, EventCounter, MetricsExporter}

  def start_link(arg, options \\ []) do
    Supervisor.start_link(__MODULE__, arg, options)
  end

  defmodule FrontendSupervisor do
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
