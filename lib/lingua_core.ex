defmodule Lingua do
  @moduledoc """
  The AI-Powered Translation Build Tool
  
  Generate professional translations at build time, not runtime.
  
  Developer writes code → CI/CD runs lingua → Static translation files → Runtime reads files
  
  ## Key Features
  
  - Zero runtime overhead - translations generated at build time
  - AI-powered translation using Bumblebee/Nx
  - CI/CD integration with Mix tasks
  - Support for multiple output formats (.po, .json, .yaml)
  - Quality validation and checking
  """

  @doc """
  Get the version of Lingua
  """
  def version, do: "0.1.0"
end
