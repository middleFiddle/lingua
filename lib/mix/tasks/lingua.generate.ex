defmodule Mix.Tasks.Lingua.Generate do
  @moduledoc """
  Generate translation output files with flexible directory templates.

  ## Usage

      mix lingua.generate
      mix lingua.generate --format=json
      mix lingua.generate --output-template="{source_dir}/locales/{lang}/{relative_path}"
      mix lingua.generate --flat-structure --output-dir="public/locales"
      mix lingua.generate --namespace-by-file

  ## Options

    * `--format` - Output format: json (default), po, yaml
    * `--output` - Output directory (default: {source_dir}/translations)
    * `--output-template` - Template for output paths using variables
    * `--flat-structure` - Generate flat files per language (no directory structure)
    * `--namespace-by-file` - Include filename in the path structure
    * `--source-lang` - Source language code (default: en)

  ## Template Variables

    * `{source_dir}` - Original source directory path
    * `{lang}` - Language code (en, es, fr, etc.)
    * `{relative_path}` - File path relative to source directory
    * `{filename}` - File name without extension
    * `{format}` - Output format extension (json, po, yaml)

  ## Template Examples

      # React i18next structure (within source directory)
      --output-template="public/locales/{lang}/{filename}.{format}"
      
      # Vue i18n structure (within source directory)  
      --output-template="i18n/{lang}/{filename}.{format}"
      
      # Rails i18n structure (within source directory)
      --output-template="config/locales/{filename}.{lang}.{format}"
      
      # Custom translations directory
      --output-template="locales/{lang}/{relative_path}"

  ## Output Formats

    * `json` - Key-value JSON files (default)
    * `po` - GNU gettext format (.po files)
    * `yaml` - YAML format files

  This task generates the final translation files that your application will use at runtime.
  Run `mix lingua.translate` first to generate translations.
  """

  @shortdoc "Generate translation output files"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, _args, _} = OptionParser.parse(args,
      switches: [
        format: :string, 
        output: :string, 
        source_lang: :string,
        output_template: :string,
        flat_structure: :boolean,
        namespace_by_file: :boolean
      ],
      aliases: [f: :format, o: :output, s: :source_lang, t: :output_template]
    )
    
    Lingua.Generator.generate(opts)
  end
end