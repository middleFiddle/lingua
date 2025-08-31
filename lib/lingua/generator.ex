defmodule Lingua.Generator do
  @moduledoc """
  Generates translation output files in various formats.
  
  Supported formats:
  - .po (GNU gettext format)
  - .json (Key-value pairs)
  - .yaml (YAML format)
  """

  require Logger

  def generate(opts \\ []) do
    format = Keyword.get(opts, :format, "json")
    source_lang = Keyword.get(opts, :source_lang, "en")
    
    # Load translations and extracted strings
    translations_file = Path.join([System.tmp_dir!(), "lingua_translations.json"])
    strings_file = Path.join([System.tmp_dir!(), "lingua_strings.json"])
    
    unless File.exists?(translations_file) do
      Logger.error("No translations found. Run 'lingua translate' first.")
      System.halt(1)
    end
    
    unless File.exists?(strings_file) do
      Logger.error("No extracted strings found. Run 'lingua extract' first.")
      System.halt(1)
    end
    
    # Load both files
    translations_data = translations_file |> File.read!() |> Jason.decode!()
    strings_data = strings_file |> File.read!() |> Jason.decode!()
    
    translations = translations_data["translations"]
    source_directory = strings_data["source_directory"]
    file_mapping = strings_data["file_mapping"] || %{}
    
    # Handle output directory and template options
    output_config = determine_output_config(opts, source_directory)
    
    Logger.info("Generating #{format} files for #{map_size(translations)} languages + source with 1:1 mapping")
    Logger.info("Output strategy: #{output_config.strategy}")
    
    # Generate source language files (keys = values) with flexible mapping
    generate_source_files_flexible(strings_data["strings"], source_lang, format, source_directory, file_mapping, output_config)
    
    # Generate translated files for each language with flexible mapping
    translations
    |> Task.async_stream(
      fn {lang_code, lang_translations} ->
        generate_translated_files_flexible(lang_code, lang_translations, format, source_directory, file_mapping, output_config)
        lang_code
      end,
      max_concurrency: System.schedulers_online() * 2,
      timeout: :infinity,
      ordered: false
    )
    |> Enum.each(fn {:ok, lang_code} ->
      Logger.info("Generated translations for #{lang_code}")
    end)
    
    Logger.info("Translation files generated successfully")
  end

  defp generate_source_files(_strings, source_lang, format, output_dir, source_directory, file_mapping) do
    # Create 1:1 file mapping for source language (keys = values)
    Logger.info("Generating source files with 1:1 file mapping...")
    
    file_mapping
    |> Task.async_stream(
      fn {file_path, file_strings} ->
        generate_source_file_for_file(file_path, file_strings, source_lang, format, output_dir, source_directory)
      end,
      max_concurrency: System.schedulers_online() * 2,
      timeout: :infinity,
      ordered: false
    )
    |> Enum.each(fn {:ok, output_file} ->
      Logger.info("Generated source file #{output_file}")
    end)
  end

  # Template processing functions
  defp determine_output_config(opts, source_directory) do
    cond do
      template = opts[:output_template] ->
        %{strategy: :template, template: template, source_directory: source_directory}
      
      opts[:flat_structure] ->
        # Always relative to source directory
        relative_output = opts[:output] || "locales"
        output_dir = if Path.type(relative_output) == :absolute do
          relative_output
        else
          Path.join(source_directory, relative_output)
        end
        %{strategy: :flat, output_dir: output_dir, source_directory: source_directory}
      
      opts[:namespace_by_file] ->
        # Always relative to source directory  
        relative_output = opts[:output] || "translations"
        output_dir = if Path.type(relative_output) == :absolute do
          relative_output
        else
          Path.join(source_directory, relative_output)
        end
        %{strategy: :namespaced, output_dir: output_dir, source_directory: source_directory}
      
      true ->
        output_dir = opts[:output] || Path.join(source_directory, "translations")
        %{strategy: :default, output_dir: output_dir, source_directory: source_directory}
    end
  end

  defp generate_source_files_flexible(_strings, source_lang, format, source_directory, file_mapping, output_config) do
    Logger.info("Generating source files with #{output_config.strategy} strategy...")
    
    file_mapping
    |> Task.async_stream(
      fn {file_path, file_strings} ->
        generate_source_file_flexible(file_path, file_strings, source_lang, format, source_directory, output_config)
      end,
      max_concurrency: System.schedulers_online() * 2,
      timeout: :infinity,
      ordered: false
    )
    |> Enum.each(fn {:ok, output_file} ->
      Logger.info("Generated source file #{output_file}")
    end)
  end

  defp generate_translated_files_flexible(lang_code, lang_translations, format, source_directory, file_mapping, output_config) do
    Logger.info("Generating translated files for #{lang_code} with #{output_config.strategy} strategy...")
    
    # Convert translations list to lookup map
    translations_lookup = 
      lang_translations
      |> Enum.map(fn %{"original" => original, "translation" => translation} ->
        {original, translation}
      end)
      |> Enum.into(%{})
    
    # Process each source file concurrently 
    file_mapping
    |> Task.async_stream(
      fn {file_path, file_strings} ->
        generate_translated_file_flexible(file_path, file_strings, lang_code, format, source_directory, translations_lookup, output_config)
      end,
      max_concurrency: System.schedulers_online() * 2,
      timeout: :infinity,
      ordered: false
    )
    |> Enum.each(fn {:ok, output_file} ->
      Logger.info("Generated translated file #{output_file}")
    end)
  end

  defp generate_source_file_flexible(file_path, file_strings, source_lang, format, source_directory, output_config) do
    output_path = resolve_output_path(file_path, source_lang, format, source_directory, output_config)
    
    # Ensure directory exists
    output_path |> Path.dirname() |> File.mkdir_p!()
    
    # Create source translations (keys = values) with unique strings
    unique_strings = file_strings |> Enum.uniq()
    source_translations = unique_strings |> Enum.map(&{&1, &1}) |> Enum.into(%{})
    
    write_file_content(output_path, source_translations, source_lang, format)
    output_path
  end

  defp generate_translated_file_flexible(file_path, file_strings, lang_code, format, source_directory, translations_lookup, output_config) do
    output_path = resolve_output_path(file_path, lang_code, format, source_directory, output_config)
    
    # Ensure directory exists
    output_path |> Path.dirname() |> File.mkdir_p!()
    
    # Get translations for this file's strings (with fallback to original)
    unique_strings = file_strings |> Enum.uniq()
    file_translations = 
      unique_strings 
      |> Enum.map(fn original_string ->
        translation = Map.get(translations_lookup, original_string, original_string)
        {original_string, translation}
      end)
      |> Enum.into(%{})
    
    write_file_content(output_path, file_translations, lang_code, format)
    output_path
  end

  defp resolve_output_path(file_path, lang_code, format, source_directory, output_config) do
    case output_config.strategy do
      :template ->
        resolve_template_path(file_path, lang_code, format, source_directory, output_config.template)
      
      :flat ->
        filename = Path.basename(file_path, Path.extname(file_path))
        Path.join(output_config.output_dir, "#{filename}.#{lang_code}.#{format}")
      
      :namespaced ->
        relative_path = Path.relative_to(file_path, source_directory)
        output_path = Path.rootname(relative_path) <> ".#{lang_code}.#{format}"
        Path.join(output_config.output_dir, output_path)
      
      :default ->
        relative_path = Path.relative_to(file_path, source_directory)
        output_path = Path.rootname(relative_path) <> ".#{format}"
        Path.join([output_config.output_dir, lang_code, output_path])
    end
  end

  defp resolve_template_path(file_path, lang_code, format, source_directory, template) do
    relative_path = Path.relative_to(file_path, source_directory)
    filename = Path.basename(file_path, Path.extname(file_path))
    
    resolved_template = template
    |> String.replace("{lang}", lang_code)
    |> String.replace("{relative_path}", Path.rootname(relative_path) <> ".#{format}")
    |> String.replace("{filename}", filename)
    |> String.replace("{format}", format)
    
    # Always resolve relative to source directory
    Path.join(source_directory, resolved_template)
  end

  defp write_file_content(output_path, translations_map, lang_code, format) do
    case format do
      "json" ->
        content = Jason.encode!(translations_map, pretty: true)
        File.write!(output_path, content)
      
      "po" ->
        content = generate_po_content_from_map(translations_map, lang_code)
        File.write!(output_path, content)
      
      "yaml" ->
        content = generate_yaml_content(translations_map, lang_code)
        File.write!(output_path, content)
    end
  end

  defp generate_source_file_for_file(file_path, file_strings, source_lang, format, output_dir, source_directory) do
    # Convert file path to relative output path
    relative_path = Path.relative_to(file_path, source_directory)
    output_path = Path.rootname(relative_path) <> case format do
      "json" -> ".json"
      "po" -> ".po"
      _ -> ".json"
    end
    
    full_output_path = Path.join([output_dir, source_lang, output_path])
    
    # Ensure directory exists
    full_output_path |> Path.dirname() |> File.mkdir_p!()
    
    # Create source translations (keys = values) with unique strings
    unique_strings = file_strings |> Enum.uniq()
    source_translations = unique_strings |> Enum.map(&{&1, &1}) |> Enum.into(%{})
    
    case format do
      "json" ->
        content = Jason.encode!(source_translations, pretty: true)
        File.write!(full_output_path, content)
      
      "po" ->
        content = generate_po_content_from_map(source_translations, source_lang)
        File.write!(full_output_path, content)
    end
    
    full_output_path
  end

  defp generate_translated_files(lang_code, lang_translations, format, output_dir, source_directory, file_mapping) do
    Logger.info("Generating translated files for #{lang_code} with 1:1 file mapping...")
    
    # Convert translations list to lookup map
    translations_lookup = 
      lang_translations
      |> Enum.map(fn %{"original" => original, "translation" => translation} ->
        {original, translation}
      end)
      |> Enum.into(%{})
    
    # Process each source file concurrently 
    file_mapping
    |> Task.async_stream(
      fn {file_path, file_strings} ->
        generate_translated_file_for_file(file_path, file_strings, lang_code, format, output_dir, source_directory, translations_lookup)
      end,
      max_concurrency: System.schedulers_online() * 2,
      timeout: :infinity,
      ordered: false
    )
    |> Enum.each(fn {:ok, output_file} ->
      Logger.info("Generated translated file #{output_file}")
    end)
  end

  defp generate_translated_file_for_file(file_path, file_strings, lang_code, format, output_dir, source_directory, translations_lookup) do
    # Convert file path to relative output path
    relative_path = Path.relative_to(file_path, source_directory)
    output_path = Path.rootname(relative_path) <> case format do
      "json" -> ".json"
      "po" -> ".po"
      _ -> ".json"
    end
    
    full_output_path = Path.join([output_dir, lang_code, output_path])
    
    # Ensure directory exists
    full_output_path |> Path.dirname() |> File.mkdir_p!()
    
    # Get translations for this file's strings (with fallback to original)
    unique_strings = file_strings |> Enum.uniq()
    file_translations = 
      unique_strings 
      |> Enum.map(fn original_string ->
        translation = Map.get(translations_lookup, original_string, original_string)
        {original_string, translation}
      end)
      |> Enum.into(%{})
    
    case format do
      "json" ->
        content = Jason.encode!(file_translations, pretty: true)
        File.write!(full_output_path, content)
      
      "po" ->
        content = generate_po_content_from_map(file_translations, lang_code)
        File.write!(full_output_path, content)
    end
    
    full_output_path
  end

  defp generate_po_content_from_map(translations_map, lang_code) do
    header = generate_po_header(lang_code)
    
    entries = 
      translations_map
      |> Enum.map(fn {original, translation} ->
        msgid = escape_po_string(original)
        msgstr = escape_po_string(translation)
        
        """
        msgid "#{msgid}"
        msgstr "#{msgstr}"
        """
      end)
      |> Enum.join("\n")
    
    header <> "\n\n" <> entries
  end

  defp generate_output_file(lang_code, translations, "po", output_dir) do
    lang_dir = Path.join([output_dir, lang_code, "LC_MESSAGES"])
    File.mkdir_p!(lang_dir)
    
    output_file = Path.join(lang_dir, "default.po")
    
    content = generate_po_content(translations, lang_code)
    File.write!(output_file, content)
    
    output_file
  end

  defp generate_output_file(lang_code, translations, "json", output_dir) do
    output_file = Path.join(output_dir, "#{lang_code}.json")
    
    content = generate_json_content(translations)
    File.write!(output_file, content)
    
    output_file
  end

  defp generate_output_file(lang_code, translations, "yaml", output_dir) do
    output_file = Path.join(output_dir, "#{lang_code}.yaml")
    
    content = generate_yaml_content(translations, lang_code)
    File.write!(output_file, content)
    
    output_file
  end

  defp generate_output_file(_lang_code, _translations, format, _output_dir) do
    Logger.error("Unsupported format: #{format}")
    System.halt(1)
  end

  defp generate_po_content(translations, lang_code) do
    header = generate_po_header(lang_code)
    
    entries = 
      translations
      |> Enum.map(fn %{"original" => original, "translation" => translation} ->
        msgid = escape_po_string(original)
        msgstr = escape_po_string(translation)
        
        """
        msgid "#{msgid}"
        msgstr "#{msgstr}"
        """
      end)
      |> Enum.join("\n")
    
    header <> "\n\n" <> entries
  end

  defp generate_po_header(lang_code) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    
    """
    # Translation file generated by Lingua
    # Language: #{lang_code}
    # Generated: #{now}
    
    msgid ""
    msgstr ""
    "Content-Type: text/plain; charset=UTF-8\\n"
    "Language: #{lang_code}\\n"
    "Generated-By: Lingua v#{Lingua.version()}\\n"
    """
  end

  defp escape_po_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
    |> String.replace("\t", "\\t")
  end

  defp generate_json_content(translations) do
    translations_map = 
      translations
      |> Enum.map(fn %{"original" => original, "translation" => translation} ->
        {original, translation}
      end)
      |> Enum.into(%{})
    
    Jason.encode!(translations_map, pretty: true)
  end

  defp generate_yaml_content(translations, lang_code) do
    translations_map = 
      translations
      |> Enum.map(fn %{"original" => original, "translation" => translation} ->
        {original, translation}
      end)
      |> Enum.into(%{})
    
    yaml_data = %{
      lang_code => translations_map
    }
    
    # Simple YAML generation (could use a YAML library if needed)
    generate_simple_yaml(yaml_data)
  end

  defp generate_simple_yaml(data, indent \\ 0) do
    indent_str = String.duplicate("  ", indent)
    
    data
    |> Enum.map(fn
      {key, value} when is_map(value) ->
        "#{indent_str}#{key}:\n" <> generate_simple_yaml(value, indent + 1)
      
      {key, value} ->
        escaped_value = 
          value
          |> String.replace("\"", "\\\"")
          |> String.replace("\n", "\\n")
        
        "#{indent_str}#{key}: \"#{escaped_value}\""
    end)
    |> Enum.join("\n")
  end
end