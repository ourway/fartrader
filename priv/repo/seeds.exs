alias FarTrader.Repo
alias FarTrader.Stock
alias FarTrader.ExternalData

Repo.insert!(%FarTrader.BrokerCredentials{
  broker: "emofid",
  nickname: "amir",
  username: "4270395923",
  password: "Amir 4302"
})

## we need to get all stocks:
#
# EasyTrader.APIs.update_db_tickers()
EasyTrader.APIs.add_stocks_to_db()

Stock
|> Repo.all()
|> Enum.map(fn s ->
  Rihanna.enqueue({ExternalData, :update_stock_basic_info, [s]})
  Rihanna.enqueue({EasyTrader.APIs, :update_stock_data, [s]})
  Rihanna.enqueue({ExternalData, :update_corp_info, [s]})
end)

# EasyTrader.Auth.get_all_credentials()
