defmodule Lingua.CLI do
  @moduledoc """
  Main CLI entry point for the Lingua translation build tool.
  
  Supports the following commands:
  - `lingua setup` - Download and cache ML models
  - `lingua extract` - Extract translatable strings from code  
  - `lingua translate` - Generate AI translations
  - `lingua generate` - Output translation files
  """

  def main(args \\ []) do
    # For help and version, don't start the application
    if Enum.any?(args, &(&1 in ["--help", "-h", "--version", "-v"])) do
      handle_simple_command(args)
    else
      args
      |> parse_args()
      |> handle_command()
    end
  end
  
  defp handle_simple_command(args) do
    cond do
      Enum.any?(args, &(&1 in ["--version", "-v"])) ->
        IO.puts("Lingua v0.1.0")
        IO.puts("The AI-Powered Translation Build Tool")
      
      true ->
        print_help()
    end
  end

  defp parse_args(args) do
    {opts, command_args, _} = 
      OptionParser.parse(args, 
        switches: [
          help: :boolean,
          version: :boolean,
          to: :string,
          format: :string,
          input: :string,
          output: :string,
          quality: :boolean
        ],
        aliases: [
          h: :help,
          v: :version,
          t: :to,
          f: :format,
          i: :input,
          o: :output,
          q: :quality
        ]
      )
    
    command = List.first(command_args)
    
    %{
      command: command,
      args: command_args,
      opts: opts
    }
  end

  defp handle_command(%{opts: opts}) when is_list(opts) and length(opts) > 0 do
    cond do
      Keyword.get(opts, :version) -> 
        IO.puts("Lingua v0.1.0")
        IO.puts("The AI-Powered Translation Build Tool")
      
      Keyword.get(opts, :help) -> 
        print_help()
      
      true ->
        handle_command_with_app(opts)
    end
  end

  defp handle_command(%{command: nil}) do
    print_help()
  end

  defp handle_command(parsed_args) do
    handle_command_with_app(parsed_args)
  end
  
  defp handle_command_with_app(parsed_args) do
    # Start application for commands that need ML functionality
    Application.ensure_all_started(:lingua)
    handle_ml_command(parsed_args)
  end

  defp handle_ml_command(%{command: "setup", opts: opts}) do
    Lingua.ModelDownloader.download(opts)
  end

  defp handle_ml_command(%{command: "extract", opts: opts}) do
    Lingua.Extractor.extract(opts)
  end

  defp handle_ml_command(%{command: "translate", opts: opts}) do
    Lingua.Translator.translate(opts)
  end

  defp handle_ml_command(%{command: "generate", opts: opts}) do
    Lingua.Generator.generate(opts)
  end

  defp handle_ml_command(%{command: unknown}) do
    IO.puts("Unknown command: #{unknown}")
    IO.puts("")
    print_help()
    System.halt(1)
  end

  defp print_help do
    IO.puts("""
    Lingua - The AI-Powered Translation Build Tool
    Generate professional translations at build time, not runtime

    USAGE:
        lingua <COMMAND> [OPTIONS]

    COMMANDS:
        setup       Download and cache ML models (~1GB, cached locally)
        extract     Extract translatable strings from source code  
        translate   Generate AI translations for extracted strings
        generate    Output translation files (.po, .json, .yaml)

    OPTIONS:
        -t, --to <LANGS>        Target languages (comma-separated: es,fr,de,pt,ja)
        -f, --format <FORMAT>   Output format (po, json, yaml) [default: po]
        -i, --input <DIR>       Source directory to scan [default: lib/]
        -o, --output <DIR>      Output directory [default: priv/gettext/]
        -q, --quality           Enable quality checking
        -h, --help              Show this help message
        -v, --version           Show version information

    EXAMPLES:
        lingua setup                                # Download models (one-time setup)
        lingua extract                              # Extract strings from lib/
        lingua translate --to=es,fr,de              # Generate Spanish, French, German  
        lingua generate --format=json               # Output as JSON files

    CI/CD WORKFLOW:
        lingua setup && lingua extract && lingua translate --to=es,fr,de && lingua generate
    """)
  end
end