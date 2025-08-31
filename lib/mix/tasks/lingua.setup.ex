defmodule Mix.Tasks.Lingua.Setup do
  @moduledoc """
  Download and cache translation models for Lingua.

  ## Usage

      mix lingua.setup

  This task downloads the required ML models (~1GB) to a local cache directory.
  Models are cached between runs to avoid repeated downloads.
  """

  @shortdoc "Download and cache translation models"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    
    Lingua.ModelDownloader.download()
  end
end