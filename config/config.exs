# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :farsheed_trader,
  namespace: FarTrader,
  ecto_repos: [FarTrader.Repo]

# Configures the endpoint
config :farsheed_trader, FarTraderWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "8U9nP0d2kK2A9FNnUHL25lg2U4/EO13NxyF3/tw7f0Myo5I1BJ70YGNuqtEqNpSQ",
  render_errors: [view: FarTraderWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: FarTrader.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
