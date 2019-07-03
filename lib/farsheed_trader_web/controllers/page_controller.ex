defmodule FarTraderWeb.PageController do
  use FarTraderWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
