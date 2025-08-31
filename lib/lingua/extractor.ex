defmodule Lingua.Extractor do
  @moduledoc """
  Extracts translatable strings from source code.
  
  Supports common i18n patterns:
  - gettext() calls
  - dgettext() calls  
  - ngettext() pluralization
  - Custom marker functions
  """

  require Logger

  defp default_patterns do
    [
      # Standard gettext patterns
      ~r/gettext\(\s*"([^"]+)"\s*\)/,
      ~r/gettext\(\s*'([^']+)'\s*\)/,
      
      # Domain gettext patterns
      ~r/dgettext\(\s*"[^"]+"\s*,\s*"([^"]+)"\s*\)/,
      ~r/dgettext\(\s*'[^']+'\s*,\s*'([^']+)'\s*\)/,
      
      # Ngettext patterns (singular)
      ~r/ngettext\(\s*"([^"]+)"\s*,\s*"[^"]+"\s*,\s*\d+\s*\)/,
      ~r/ngettext\(\s*'([^']+)'\s*,\s*'[^']+'\s*,\s*\d+\s*\)/,
      
      # Custom translation markers
      ~r/_\(\s*"([^"]+)"\s*\)/,
      ~r/_\(\s*'([^']+)'\s*\)/
    ]
  end

  defp i18n_patterns do
    [
      # React i18next patterns
      ~r/\bt\(\s*"([^"]+)"\s*\)/,
      ~r/\bt\(\s*'([^']+)'\s*\)/,
      
      # i18next.t patterns
      ~r/i18next\.t\(\s*"([^"]+)"\s*\)/,
      ~r/i18next\.t\(\s*'([^']+)'\s*\)/,
      
      # useTranslation hook patterns
      ~r/\{\s*t\(\s*"([^"]+)"\s*\)\s*\}/,
      ~r/\{\s*t\(\s*'([^']+)'\s*\)\s*\}/
    ]
  end

  def extract(opts \\ []) do
    input_dir = Keyword.get(opts, :input, "lib/")
    pattern_type = Keyword.get(opts, :patterns, "gettext") # "gettext" or "i18n"
    
    Logger.info("Extracting translatable strings from #{input_dir} using #{pattern_type} patterns")
    
    # Get files and extract with CONCURRENT processing! 🚀
    files = find_source_files(input_dir, pattern_type)
    Logger.info("Processing #{length(files)} files concurrently...")
    
    file_strings_map = 
      files
      |> Task.async_stream(
        &extract_from_file(&1, pattern_type),
        max_concurrency: System.schedulers_online() * 2,
        timeout: :infinity,
        ordered: false
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.filter(fn {_file, strings} -> length(strings) > 0 end)
      |> Enum.into(%{})
    
    all_strings = 
      file_strings_map
      |> Map.values()
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()
    
    Logger.info("Found #{length(all_strings)} unique strings across #{map_size(file_strings_map)} files")
    
    # Save with file mapping for 1:1 generation
    output_file = Path.join([System.tmp_dir!(), "lingua_strings.json"])
    
    strings_data = %{
      extracted_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      source_directory: input_dir,
      pattern_type: pattern_type,
      strings: all_strings,
      file_mapping: file_strings_map
    }
    
    File.write!(output_file, Jason.encode!(strings_data, pretty: true))
    
    Logger.info("Extracted strings saved to #{output_file}")
    
    all_strings
  end

  defp find_source_files(dir, pattern_type \\ "gettext") do
    extensions = case pattern_type do
      "i18n" -> [".js", ".jsx", ".ts", ".tsx", ".vue"]
      _ -> [".ex", ".exs", ".eex", ".leex", ".heex"]
    end
    
    dir
    |> Path.expand()
    |> File.ls!()
    |> Enum.flat_map(fn item ->
      path = Path.join(dir, item)
      
      cond do
        File.dir?(path) and not String.starts_with?(item, ".") ->
          find_source_files(path, pattern_type)
        
        File.regular?(path) and String.ends_with?(path, extensions) ->
          [path]
        
        true ->
          []
      end
    end)
  rescue
    File.Error ->
      Logger.warning("Could not access directory: #{dir}")
      []
  end

  defp extract_from_file(file_path, pattern_type \\ "gettext") do
    Logger.debug("Scanning file: #{file_path}")
    
    strings = 
      file_path
      |> File.read!()
      |> extract_strings_from_content(file_path, pattern_type)
    
    {file_path, strings}
  rescue
    e ->
      Logger.warning("Could not read file #{file_path}: #{Exception.message(e)}")
      {file_path, []}
  end

  defp extract_strings_from_content(content, file_path, pattern_type \\ "gettext") do
    patterns = case pattern_type do
      "i18n" -> i18n_patterns()
      _ -> default_patterns()
    end
    
    patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, content, capture: :all_but_first)
      |> Enum.map(fn [string] -> 
        %{
          string: string,
          file: file_path,
          pattern: inspect(pattern)
        }
      end)
    end)
    |> Enum.map(& &1.string)
  end
end