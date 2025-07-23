defmodule Semigraph.Repo do
  use Ecto.Repo,
    otp_app: :semigraph,
    adapter: Ecto.Adapters.Postgres
end
