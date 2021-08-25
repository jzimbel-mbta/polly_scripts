defmodule PollyScripts.MixProject do
  use Mix.Project

  def project do
    [
      app: :polly_scripts,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {PollyScripts, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.2"},
      {:httpoison, "~> 1.8"},
      {:ex_aws, "~> 2.2"},
      {:ex_aws_polly, "~> 0.4.0"}
    ]
  end
end
