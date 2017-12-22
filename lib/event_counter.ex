defmodule MarathonEventExporter.EventCounter do
  @moduledoc """
  A GenServer to receive events from the event stream and keep a count of events
  by event type.
  """

  use GenServer

  alias MarathonEventExporter.SSEParser.Event

  ## Client API

  def start_link(_arg, options \\ []) do
    GenServer.start_link(__MODULE__, :ok, options)
  end

  @doc "Get the mapping of all event types to counts."
  def event_counts(ec), do: GenServer.call(ec, :event_counts)

  ## Server callbacks

  def init(:ok), do: {:ok, %{}}

  def handle_info({:sse, %Event{event: event}}, state),
    do: {:noreply, Map.update(state, event, 1, &(&1 + 1))}

  def handle_call(:event_counts, _from, state), do: {:reply, state, state}
end
