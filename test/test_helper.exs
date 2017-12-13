defmodule EventCatcher do
  @moduledoc """
  A listener that stashes received events.
  """
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, [], opts)
  def events(server), do: GenServer.call(server, :events)

  def handle_call(:events, _from, events), do: {:reply, events, events}
  def handle_info({:sse, event}, events), do: {:noreply, [event | events]}
end

defmodule FakeMarathon do
  @moduledoc """
  A fake Marathon API that can stream events.
  """
  use GenServer
  require Logger

  defmodule HandlerState do
    defstruct stream_handler: nil, delay: nil
  end

  defmodule SSEHandler do
    def init(req, state) do
      # state.delay is nil (which is falsey) or an integer (which is truthy).
      if state.delay, do: Process.sleep(state.delay)
      new_req = :cowboy_req.stream_reply(
        200, %{"content-type" => "text/event-stream"}, req)
      FakeMarathon.sse_stream(state.stream_handler, self())
      {:cowboy_loop, new_req, state}
    end

    def info(:keepalive, req, state) do
      :cowboy_req.stream_body("\r\n", :nofin, req)
      {:ok, req, state}
    end

    def info({:event, event, data}, req, state) do
      ev = "event: #{event}\r\ndata: #{data}\r\n\r\n"
      :cowboy_req.stream_body(ev, :nofin, req)
      {:ok, req, state}
    end

    def info(:close, req, state) do
      {:stop, req, state}
    end

    ## Client API

    def keepalive(handler), do: send(handler, :keepalive)
    def event(handler, {:event, _, _}=event), do: send(handler, event)
    def close(handler), do: send(handler, :close)
  end

  defmodule State do
    defstruct listener: nil, port: nil, sse_streams: []
  end

  ## Client

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end
  def port(fm), do: GenServer.call(fm, :port)
  def base_url(fm), do: "http://localhost:#{port(fm)}"
  def event(fm, event, data), do: GenServer.call(fm, {:event, event, data})
  def end_stream(fm), do: GenServer.call(fm, :end_stream)
  def sse_stream(fm, pid), do: GenServer.call(fm, {:sse_stream, pid})

  ## Callbacks

  def init(opts) do
    # Trap exits so terminate/2 gets called reliably.
    Process.flag(:trap_exit, true)
    handler_state = %HandlerState{
      stream_handler: self(),
      delay: Keyword.get(opts, :response_delay),
    }
    handlers = [
      {"/v2/events", SSEHandler, handler_state},
    ]
    dispatch = :cowboy_router.compile([{:_, handlers}])
    listener_ref = make_ref()
    {:ok, listener} = :cowboy.start_clear(
      listener_ref, [], %{env: %{dispatch: dispatch}})
    Process.link(listener)
    {:ok, %State{listener: listener_ref, port: :ranch.get_port(listener_ref)}}
  end

  def terminate(reason, state) do
    :cowboy.stop_listener(state.listener)
    reason
  end

  def handle_call(:port, _from, state), do: {:reply, state.port, state}

  def handle_call({:sse_stream, pid}, _from, state) do
    Logger.debug("FakeMarathon.sse_stream: #{inspect pid}")
    new_state = %{state | sse_streams: [pid | state.sse_streams]}
    {:reply, :ok, new_state}
  end

  def handle_call({:event, _, _}=event, _from, state) do
    Logger.debug("FakeMarathon.event: #{inspect event}")
    Enum.each(state.sse_streams, &SSEHandler.event(&1, event))
    {:reply, :ok, state}
  end

  def handle_call(:end_stream, _from, state) do
    Enum.each(state.sse_streams, &SSEHandler.close/1)
    {:reply, :ok, state}
  end
end

defmodule TestHelpers do
  alias MarathonEventExporter.SSEParser.Event

  @doc """
  Build a Marathon event from the given type and fields.

  The :eventType field is always added/overridden, the :timestamp field is
  added if one is not provided.
  """
  def marathon_event(event_type, fields) do
    {:ok, data} = Map.new(fields)
    |> Map.put_new(:timestamp, DateTime.utc_now |> DateTime.to_iso8601)
    |> Map.put(:eventType, event_type)
    |> JSX.encode
    %Event{event: event_type, data: data}
  end
end

ExUnit.start()
