defmodule MarathonEventExporter.MarathonClient do
  @moduledoc """
  A (very partial) Marathon REST API client.

  This exists mostly just to stream events.
  """

  # The logging "functions" are actually macros, so we need to `require Logger`
  # in order to access them.
  require Logger

  defmodule StreamCatcher do
    @moduledoc """
    A GenServer to receive async responses from the HTTP client and forward the
    data chunks to the SSE parser.
    """

    use GenServer

    alias MarathonEventExporter.SSEParser

    ## Client API

    @doc """
    Starts a new StreamCatcher.
    """
    def start_link({url, listeners}, opts \\ []) do
      GenServer.start_link(__MODULE__, {url, listeners}, opts)
    end


    ## Server callbacks

    def init({url, listeners}) do
      headers = %{"Accept" => "text/event-stream"}
      {:ok, ssep} = SSEParser.start_link([])
      Enum.each(listeners, fn l -> SSEParser.register_listener(ssep, l) end)
      r = HTTPoison.get!(url, headers, stream_to: self(), recv_timeout: 60_000)
      {:ok, {r, ssep}}
    end

    def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, {_, ssep}=state) do
      SSEParser.feed_data(ssep, chunk)
      {:noreply, state}
    end

    def handle_info(msg, state) do
      Logger.debug("msg: #{inspect msg}")
      {:noreply, state}
    end
  end

  def stream_events(base_url, listeners) do
    StreamCatcher.start_link({base_url <> "/v2/events", listeners})
  end
end
