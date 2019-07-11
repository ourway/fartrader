defmodule FarTrader.ExternalConnections do
  @moduledoc false
  alias FarTrader.Utils

  @spec get_asanbours_results(binary()) :: map()
  def get_asanbours_results(filter_uuid) do
    url = "https://asanbourse.ir/api/ShareDiagram/ShareGetAllResult"

    headers = [
      Authorization:
        "Bearer ABsW5DWWbSSDEke_ajFbFkzinq_hNY3_PpYT7Z0ir6dPVnRmMrxLEt5Ra0RZMmj1NH3SAw2obUsxfp8bFajMMcsocdAHjAU6VaYGgFyxTEPqHhKFJpLiaVX1s29VBwQ-1VTluY3LLYJXbKYtbTui-gMt8FozLk9aydokUuOnbl-tgMerVGB-VA0hhArboeqtUMfJhaX2KqwUI6m2Xc2XfB9168Dk5nD593aSGkDXU3kn_W35xkCy-Pd9-WBWv0Jaq4T27fDe4BfEzBHmA5tpRTOCrr_tyrTPwg4SrmOx9r9DGahRmhvmC9yx8WA67hRVJg6nvyfIOdiENA4qWDcMWD4Z_bOMvIp7wh3KFDENz7Ztte4i55ZJoU-PrwsCzdcQTLKVibXShGAt965lwXL5hHd_80raGTDNIkCTxE9fk7NWj4TL7WRXWVjKDvh9g1fBYDV-z6BJ706iHFfkO8y83AktM7G4RCfS2nmeg3pcMsefrOrTAtu3LPL1--CPGP0UlWaoTB5sxZGLk3-gsemZGza-ho_8F02st6-VbxveJ3dnenv98H-lzkRzYjy17DSwwF3rLx13yvJe2kNqc6Yl80_TexkwLUzBCifbiR45H1PKuvqfgqPm7ldCii2t2qWr3VLyY5RiqWRPbfRKapj88Q",
      "Content-Type": "Application/json; Charset=utf-8"
    ]

    {:ok, data} = [%{id: filter_uuid}] |> Jason.encode()
    HTTPoison.post(url, data, headers)
  end

  @doc """
    fetches symbol history from tse.ir api.
    sample page is `http://tse.ir/json/Instrument/TradeHistory/TradeHistory_IRO1NIRO0001.html`
    example:
      
      iex> FarTrader.ExternalConnections.get_symbol_history("IRO1SIPA0001", 1398, 4)
  """
  @spec get_symbol_history(binary()) :: map()
  def get_symbol_history(isin) do
    url =
      "http://tse.ir/json/Instrument/TradeHistory/TradeHistory_#{isin |> String.upcase()}.html"

    resp = Utils.http_get(url)

    case resp.status_code do
      200 ->
        resp.body |> Floki.parse() |> Floki.find("table tbody tr")

      _ ->
        :not_found
    end
  end
end
