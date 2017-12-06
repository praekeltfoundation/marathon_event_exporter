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

  defmodule HelloHandler do
    def init(req, state) do
      new_req = :cowboy_req.reply(
        200,
        %{"content-type" => "text/html"}, "hello", req)
      {:ok, new_req, state}
    end
  end

  defmodule SSEHandler do
    def init(req, state) do
      new_req = :cowboy_req.stream_reply(
        200, %{"content-type" => "text/event-stream"}, req)
      FakeMarathon.sse_stream(:fake_marathon, self())
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
  end

  defmodule State do
    defstruct port: nil, sse_streams: []
  end

  ## Client

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: :fake_marathon)
  end
  def port(fm), do: GenServer.call(fm, :port)
  def base_url(fm), do: "http://localhost:#{port(fm)}"
  def event(fm, event, data), do: GenServer.call(fm, {:event, event, data})
  def sse_stream(fm, pid), do: GenServer.call(fm, {:sse_stream, pid})

  ## Callbacks

  def init(:ok) do
    handlers = [
      {"/", HelloHandler, []},
      {"/v2/events", SSEHandler, []},
    ]
    dispatch = :cowboy_router.compile([{:_, handlers}])
    {:ok, listener} = :cowboy.start_clear(
      :fm_listener, [], %{env: %{dispatch: dispatch}})
    Process.link(listener)
    {:ok, %State{port: :ranch.get_port(:fm_listener)}}
  end

  def handle_call(:port, _from, state), do: {:reply, state.port, state}

  def handle_call({:sse_stream, pid}, _from, state) do
    new_state = %{state | sse_streams: [pid | state.sse_streams]}
    {:reply, :ok, new_state}
  end

  def handle_call({:event, _, _}=event, _from, state) do
    Enum.each(state.sse_streams, fn s -> send(s, event) end)
    {:reply, :ok, state}
  end
end

ExUnit.start()
