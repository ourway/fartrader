use Mix.Config

# Configure your database
config :farsheed_trader, FarTrader.Repo,
  username: "postgres",
  password: "postgres",
  database: "farsheed_trader_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :farsheed_trader, FarTraderWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
