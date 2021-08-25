defmodule PollyScripts.Polly.QuotaTracker do
  @moduledoc false

  use GenServer

  ## Client ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def put_transaction(server \\ __MODULE__, engine) do
    GenServer.call(server, {:put_transaction, engine}, :infinity)
  end

  ## Server ---

  @max_tps_by_engine %{
    standard: 80,
    neural: 8
  }

  @type state :: {
          %{standard: non_neg_integer, neural: non_neg_integer},
          %{standard: [GenServer.from()], neural: [GenServer.from()]}
        }

  @impl true
  def init(:ok) do
    {:ok, {%{standard: 0, neural: 0}, %{standard: [], neural: []}}}
  end

  @impl true
  def handle_call({:put_transaction, engine}, from, {counts, waiting}) do
    if counts[engine] < @max_tps_by_engine[engine] do
      {:noreply, {counts, waiting}, {:continue, {:increment, engine, from}}}
    else
      {:noreply, {counts, enqueue(waiting, engine, from)}}
    end
  end

  @impl true
  def handle_continue({:increment, _, nil}, state), do: {:noreply, state}

  def handle_continue({:increment, engine, from}, {counts, waiting}) do
    Process.send_after(self(), {:decrement, engine}, 1000 + Enum.random(10..100))
    GenServer.reply(from, :ok)
    {:noreply, {increment(counts, engine), waiting}}
  end

  @impl true
  def handle_info({:decrement, engine}, {counts, waiting}) do
    {waiting, from} = dequeue(waiting, engine)
    {:noreply, {decrement(counts, engine), waiting}, {:continue, {:increment, engine, from}}}
  end

  defp increment(counts, engine) do
    %{counts | engine => counts[engine] + 1}
  end

  defp decrement(counts, engine) do
    %{counts | engine => counts[engine] - 1}
  end

  defp enqueue(waiting, engine, from) do
    %{waiting | engine => waiting[engine] ++ [from]}
  end

  defp dequeue(waiting, engine) do
    case waiting[engine] do
      [] -> {waiting, nil}
      [from | rest] -> {%{waiting | engine => rest}, from}
    end
  end
end
