defmodule FarTrader.Repo do
  use Ecto.Repo,
    otp_app: :farsheed_trader,
    adapter: Ecto.Adapters.Postgres
end
