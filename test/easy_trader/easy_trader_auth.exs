defmodule EasyTrader.AuthTest do
  use FarTrader.DataCase, async: true
  alias EasyTrader.Auth
  alias FarTrader.Utils

  setup do
    :ok
  end

  describe "pre authorization process" do
    test "login information" do
      c = Auth.get_auth_cookies() |> IO.inspect
      c |> Auth.test_successful_auth |> IO.inspect
    end
  end
end
