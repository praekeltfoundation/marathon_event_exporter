defmodule MarathonEventExporter.EventCounter do
  @moduledoc """
  A GenServer to receive events from the event stream and keep a count of events
  by event type.
  """

  use GenServer

  ## Client API

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, :ok)
  end

  @doc "Get the mapping of all event types to counts."
  def event_counts(ec), do: GenServer.call(ec, :event_counts)

  ## Server callbacks

  defmodule CounterAgent do
    @moduledoc """
    Agent to keep a mapping of event type to a count of the number of times that
    event has occurred.
    """
    use Agent

    alias MarathonEventExporter.SSEParser.Event

    def start_link(_arg) do
      Agent.start_link(fn -> %{} end, name: __MODULE__)
    end

    @doc """
    Increment the count of the number of times an event type has occurred.
    """
    def increment_event(ma, %Event{event: event}) do
      Agent.update(ma, fn state -> Map.update(state, event, 1, &(&1 + 1)) end)
    end

    def get_events(ma), do:  Agent.get(ma, fn state -> state end)
  end

  defmodule State do
    defstruct counter_agent: nil
  end

  def init(:ok) do
    {:ok, counter_agent} = CounterAgent.start_link(:ok)
    {:ok, %State{counter_agent: counter_agent}}
  end

  def handle_info({:sse, event}, state) do
    CounterAgent.increment_event(state.counter_agent, event)
    {:noreply, state}
  end

  def handle_call(:event_counts, _from, state) do
    event_counts = CounterAgent.get_events(state.counter_agent)
    {:reply, event_counts, state}
  end
end
