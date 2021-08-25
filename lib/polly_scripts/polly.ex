defmodule PollyScripts.Polly do
  @moduledoc false

  alias PollyScripts.Polly.QuotaTracker

  @lexicon_names ["mbtalexicon"]

  @type text_type :: :text | :ssml

  @type engine :: :standard | :neural

  @type opt :: {:text_type, text_type} | {:engine, engine}

  @doc """
  Passes a piece of text through Polly. This function may block for
  some amount of time, as it has rate limiting built in to stay below
  Polly's per-second request quotas.
  """
  @spec synthesize(String.t(), [opt]) :: {:ok, binary} | {:error, any}
  def synthesize(string, opts \\ []) do
    text_type = opts[:text_type] || :text
    engine = opts[:engine] || :standard

    string
    |> ExAws.Polly.synthesize_speech(
      lexicon_names: @lexicon_names,
      text_type: Atom.to_string(text_type),
      engine: Atom.to_string(engine)
    )
    |> tap(fn _ -> QuotaTracker.put_transaction(engine) end)
    |> ExAws.request()
    |> case do
      {:ok, %{body: audio_data}} -> {:ok, audio_data}
      {:error, reason} -> {:error, reason}
    end
  end
end
