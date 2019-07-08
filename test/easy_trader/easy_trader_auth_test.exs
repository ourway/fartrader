defmodule EasyTrader.AuthTest do
  use FarTrader.DataCase, async: true
  alias EasyTrader.Auth
  alias FarTrader.Utils

  setup do
    :ok
  end

  describe "authorization process" do
    test "successful login" do
      username = "4270395923"
      password = "Amir 4302"
      c = Auth.do_all(username, password)
      resp = c |> Auth.test_successful_auth()
      assert resp.body |> Jason.decode!() |> Map.get("isSuccessfull") == true
    end
  end
end
