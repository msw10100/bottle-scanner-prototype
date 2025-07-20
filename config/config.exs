import Config

# Configures the endpoint
config :bottle_scanner_prototype, BottleScannerPrototypeWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BottleScannerPrototypeWeb.ErrorHTML, json: BottleScannerPrototypeWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: BottleScannerPrototype.PubSub,
  live_view: [signing_salt: "K8xjO4mQ"]

# Configure PubSub - no longer needed, configured in application.ex

# Minimal configuration for Chorus
config :chorus,
  # Set observability to minimal as requested
  observability: %{
    level: :minimal
  },
  
  # Minimal telemetry configuration
  telemetry: %{
    level: :minimal
  },
  
  # Basic runtime configuration without external services
  runtime: [
    # Use in-memory adapters to avoid external dependencies
    queue_adapter: :in_memory,
    storage_adapter: :in_memory
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"