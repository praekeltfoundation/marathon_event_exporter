defmodule MarathonEventExporter do
  @moduledoc """
  Documentation for MarathonEventExporter.

  TODO: Write something here.
  """

  use Application

  alias MarathonEventExporter.Supervisor

  defp get_config(key), do: Application.fetch_env!(:marathon_event_exporter, key)

  # Application callbacks

  def start(_type, _args) do
    config = {
      get_config(:marathon_url),
      get_config(:stream_timeout),
      get_config(:exporter_port),
    }
    Supervisor.start_link(config, name: Supervisor)
  end
end
