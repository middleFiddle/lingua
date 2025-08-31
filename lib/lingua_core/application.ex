defmodule Lingua.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Model downloader coordination when needed
    ]

    opts = [strategy: :one_for_one, name: Lingua.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
