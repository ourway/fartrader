alias FarTrader.Repo

Repo.insert!(%FarTrader.BrokerCredentials{
  broker: "emofid",
  nickname: "amir",
  username: "4270395923",
  password: "Amir 4302"
})

## we need to get all stocks:
#
EasyTrader.APIs.update_db_tickers()

# EasyTrader.Auth.get_all_credentials()
