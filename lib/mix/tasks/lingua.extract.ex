defmodule Mix.Tasks.Lingua.Extract do
  @moduledoc """
  Extract translatable strings from source code.

  ## Usage

      mix lingua.extract
      mix lingua.extract --input=lib/
      mix lingua.extract --input=web/

  ## Options

    * `--input` - Source directory to scan for translatable strings (default: lib/)

  This task scans your source code for gettext calls and other translation markers,
  extracting all translatable strings for processing by the translation engine.
  """

  @shortdoc "Extract translatable strings from source code"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, _args, _} = OptionParser.parse(args, 
      switches: [input: :string, source_dir: :string, pattern_type: :string, patterns: :string],
      aliases: [i: :input]
    )
    
    # Handle different option names for source directory
    input_dir = opts[:source_dir] || opts[:input] || "lib/"
    pattern_type = opts[:pattern_type] || opts[:patterns] || "gettext"
    
    final_opts = [input: input_dir, patterns: pattern_type]
    
    Lingua.Extractor.extract(final_opts)
  end
end