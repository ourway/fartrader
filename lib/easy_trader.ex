defmodule EasyTrader.Auth do
  @moduledoc """
    Easy Trader Authentication process.
    this is the recepie:
      1- get a request verification token from a form input
      2- 
  """
  alias FarTrader.Utils
  @url "https://easytrader.emofid.com/Account/Login?ReturnUrl=%2Forder"


  @doc """
  this will be the the request to procced, and will get a 
  `__RequestVerificationToken` from a hidden input form and will use
  in next request
  """
  def get_form_token do
    
    base_url = "https://easytrader.emofid.com"
    postfix_url = "/Account/Login?ReturnUrl=%2Forder"
    resp = Utils.http_get(base_url <> postfix_url)
    [{_, [_, _, {_, t}], []}] = resp.body |> Floki.find("input[name=__RequestVerificationToken]")
    [next_location] = resp.body |> Floki.find("form") |> Floki.attribute("action")
    {base_url <> next_location, t}
  end
end
