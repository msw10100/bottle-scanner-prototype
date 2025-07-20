defmodule PersonalBartender.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Bandit server with tidewave MCP endpoints
      {Bandit, plug: PersonalBartender.TidewaveServer, port: 4000}
    ]

    opts = [strategy: :one_for_one, name: PersonalBartender.Supervisor]
    Supervisor.start_link(children, opts)
  end
end