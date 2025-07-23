defmodule Semigraph.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SemigraphWeb.Telemetry,
      # Semigraph.Repo,  # Commented out for now - we're not using database
      {DNSCluster, query: Application.get_env(:semigraph, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Semigraph.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Semigraph.Finch},
      # Start a worker by calling: Semigraph.Worker.start_link(arg)
      # {Semigraph.Worker, arg},
      # Start to serve requests, typically the last entry
      SemigraphWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Semigraph.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SemigraphWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
