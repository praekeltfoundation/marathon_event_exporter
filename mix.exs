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
      aliases: aliases(),
      preferred_cli_env: [
        "coveralls": :test,
        "coveralls.json": :test,
        "coveralls.detail": :test,
      ],
    ]
  end

  def aliases do
    [
      # Don't start application at test time.
      test: "test --no-start",
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {MarathonEventExporter, nil},
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:conform, "~> 2.2"},
      # 2017-12-13: The latest hackney release (1.10.1) has a bug in async
      # request cleanup: https://github.com/benoitc/hackney/issues/447 The
      # partial fix in master leaves us with a silent deadlock, so for now
      # we'll use an earlier version.
      {:hackney, "~> 1.9.0"},
      {:httpoison, "~> 0.13"},
      {:cowboy, "~> 2.1"},
      {:exjsx, "~> 4.0", only: :test},
      {:excoveralls, "~> 0.7", only: :test},
      {:distillery, "~> 1.5", runtime: false},
      {:mix_docker, "~> 0.5.0", runtime: false},
    ]
  end
end
