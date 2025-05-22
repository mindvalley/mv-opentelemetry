defmodule MvOpentelemetryHarnessWeb.Plug.CurrentUser do
  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    authorization = Plug.Conn.get_req_header(conn, "authorization")

    case authorization do
      ["auth0|test_user_id"] ->
        context = %{current_user: %{uid: "auth0|test_user_id"}}

        conn
        |> Plug.Conn.put_private(:absinthe, %{context: context})

      ["auth0|malformed"] ->
        context = %{current_user: 123}

        conn
        |> Plug.Conn.put_private(:absinthe, %{context: context})

      [] ->
        conn
    end
  end
end
