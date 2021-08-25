defmodule PollyScripts.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {PollyScripts.Polly.QuotaTracker, [name: PollyScripts.Polly.QuotaTracker]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
