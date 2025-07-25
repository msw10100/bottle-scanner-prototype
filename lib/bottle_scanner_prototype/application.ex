defmodule BottleScannerPrototype.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start Phoenix PubSub
      {Phoenix.PubSub, name: BottleScannerPrototype.PubSub},
      # Start Phoenix endpoint
      BottleScannerPrototypeWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: BottleScannerPrototype.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BottleScannerPrototypeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end