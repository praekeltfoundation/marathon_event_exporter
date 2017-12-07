defmodule MarathonEventExporter.Mixfile do
  use Mix.Project

  def project do
    [
      app: :marathon_event_exporter,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "coveralls": :test,
        "coveralls.json": :test,
        "coveralls.detail": :test,
      ],
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 0.13"},
      {:cowboy, "~> 2.1"},
      {:exjsx, "~> 4.0", only: :test},
      {:excoveralls, "~> 0.7", only: :test},
    ]
  end
end
