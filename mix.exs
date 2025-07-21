defmodule BottleScannerPrototype.MixProject do
  use Mix.Project

  def project do
    [
      app: :bottle_scanner_prototype,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :chorus],
      mod: {BottleScannerPrototype.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core Chorus dependency
      {:chorus, git: "https://github.com/msw10100/chorus", sparse: "apps/chorus"},
      # Phoenix LiveView for web interface
      {:phoenix, "~> 1.7.0"},
      {:phoenix_live_view, "~> 0.20.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:plug_cowboy, "~> 2.5"},
      # HTTP and JSON
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.4"},
      # Image processing
      {:image, "~> 0.54"},
      # XML parsing for vision API responses
      {:sweet_xml, "~> 0.7"},
      # Image processing library with Vision AI integration
      {:vix, "~> 0.26"}
    ]
  end

  defp aliases do
    [
      # Run tidewave server
      tidewave: ["run --no-halt"],

      # Kill tidewave server
      kill: ["cmd", "pkill -f 'mix tidewave' || pkill -f '_build.*chorus_interactive_app' || echo 'No server processes found'"],

      # Run with interactive shell for debugging
      interactive: ["run --no-halt --eval 'IEx.pry()'"],

      # Run tests
      test: ["test --no-start"]
    ]
  end
end
