defmodule Mix.Tasks.Lingua.Translate do
  @moduledoc """
  Generate AI translations for extracted strings.

  ## Usage

      mix lingua.translate --to=es,fr,de
      mix lingua.translate --to=pt --quality
      mix lingua.translate --to=ja,ko,zh

  ## Options

    * `--to` - Target languages (comma-separated: es,fr,de,pt,ja,it,zh,ko,ru,ar)  
    * `--quality` - Enable quality checking for translations

  ## Supported Languages

    * es - Spanish
    * fr - French  
    * de - German
    * pt - Portuguese
    * ja - Japanese
    * it - Italian
    * zh - Chinese
    * ko - Korean
    * ru - Russian
    * ar - Arabic

  This task uses AI models to translate extracted strings to the specified target languages.
  Run `mix lingua.extract` first to extract strings from your code.
  """

  @shortdoc "Generate AI translations for extracted strings"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, _args, _} = OptionParser.parse(args,
      switches: [to: :string, quality: :boolean],
      aliases: [t: :to, q: :quality]
    )
    
    Lingua.Translator.translate(opts)
  end
end