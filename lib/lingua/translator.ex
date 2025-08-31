defmodule Lingua.Translator do
  @moduledoc """
  AI-powered translation engine using Bumblebee and Nx.
  
  Supports multiple target languages with quality validation.
  Uses cached models for efficient batch translation.
  """

  require Logger

  # Translation model configuration
  @model_name "nllb-200-distilled-600M"
  @model_repo "facebook/nllb-200-distilled-600M"

  @supported_languages %{
    "es" => "Spanish",
    "fr" => "French", 
    "de" => "German",
    "pt" => "Portuguese",
    "ja" => "Japanese",
    "it" => "Italian",
    "zh" => "Chinese",
    "ko" => "Korean",
    "ru" => "Russian",
    "ar" => "Arabic"
  }

  def translate(opts \\ []) do
    target_languages = parse_target_languages(opts)
    quality_check = Keyword.get(opts, :quality, false)
    
    # Load extracted strings
    strings_file = Path.join([System.tmp_dir!(), "lingua_strings.json"])
    
    unless File.exists?(strings_file) do
      Logger.error("No extracted strings found. Run 'lingua extract' first.")
      System.halt(1)
    end
    
    strings_data = 
      strings_file
      |> File.read!()
      |> Jason.decode!()
    
    strings = strings_data["strings"]
    file_mapping = strings_data["file_mapping"] || %{}
    
    Logger.info("Translating #{length(strings)} strings to #{length(target_languages)} languages")
    Logger.info("Using concurrent translation per file per language (#{map_size(file_mapping)} files × #{length(target_languages)} languages = #{map_size(file_mapping) * length(target_languages)} concurrent tasks)")
    
    # Load translation model
    {:ok, model_info} = load_translation_model()
    
    # Create concurrent tasks for each (file, language) combination
    file_language_tasks = 
      for {file_path, file_strings} <- file_mapping,
          lang_code <- target_languages,
          do: {file_path, lang_code, file_strings}
    
    Logger.info("Starting #{length(file_language_tasks)} concurrent translation tasks...")
    
    # Process all file-language combinations concurrently
    concurrent_translations =
      file_language_tasks
      |> Task.async_stream(
        fn {file_path, lang_code, file_strings} ->
          translate_file_to_language(file_path, file_strings, lang_code, model_info, quality_check)
        end,
        max_concurrency: System.schedulers_online() * 2,
        timeout: :infinity,
        ordered: false
      )
      |> Enum.map(fn {:ok, result} -> result end)
    
    # Group results by language for output format
    translations = 
      concurrent_translations
      |> List.flatten()
      |> Enum.group_by(fn %{"language" => lang_code} -> lang_code end)
    
    # Save translations
    output_data = %{
      translated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      source_strings: length(strings),
      target_languages: target_languages,
      translations: translations
    }
    
    output_file = Path.join([System.tmp_dir!(), "lingua_translations.json"])
    File.write!(output_file, Jason.encode!(output_data, pretty: true))
    
    Logger.info("Translations saved to #{output_file}")
    
    translations
  end

  defp translate_file_to_language(file_path, file_strings, lang_code, model_info, quality_check) do
    Logger.info("Translating #{Path.basename(file_path)} to #{@supported_languages[lang_code]} (#{lang_code}) - #{length(file_strings)} strings")
    
    unique_strings = file_strings |> Enum.uniq()
    
    translations = 
      unique_strings
      |> Enum.with_index(1)
      |> Enum.map(fn {string, index} ->
        Logger.debug("File #{Path.basename(file_path)} → #{lang_code}: #{index}/#{length(unique_strings)}: #{String.slice(string, 0, 30)}...")
        
        translation = translate_string(string, lang_code, model_info)
        
        if quality_check do
          quality_score = Lingua.QualityChecker.check_translation(string, translation, lang_code)
          Logger.debug("Quality score: #{quality_score}")
        end
        
        %{
          "original" => string,
          "translation" => translation,
          "language" => lang_code
        }
      end)
    
    Logger.info("Completed #{Path.basename(file_path)} → #{lang_code}")
    translations
  end

  defp parse_target_languages(opts) do
    case Keyword.get(opts, :to) do
      nil ->
        Logger.error("No target languages specified. Use --to=es,fr,de")
        System.halt(1)
      
      languages_str ->
        languages_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(fn lang ->
          if Map.has_key?(@supported_languages, lang) do
            true
          else
            Logger.warning("Unsupported language code: #{lang}")
            false
          end
        end)
        |> case do
          [] ->
            Logger.error("No valid target languages found")
            System.halt(1)
          langs ->
            langs
        end
    end
  end

  def load_translation_model do
    try do
      # Ensure EXLA backend is set
      Nx.global_default_backend(EXLA.Backend)
      
      # Check if model is cached, download if not
      unless Lingua.ModelDownloader.model_exists?(@model_name) do
        Logger.info("Model not cached, downloading...")
        Lingua.ModelDownloader.download()
      end
      
      # Get model directory
      models_dir = Lingua.ModelDownloader.get_models_directory()
      model_path = Path.join(models_dir, @model_name)
      
      Logger.info("Loading translation model from #{model_path}")
      
      # Load model using Bumblebee
      {:ok, model_info} = Bumblebee.load_model({:hf, @model_repo})
      {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, @model_repo})
      {:ok, generation_config} = Bumblebee.load_generation_config({:hf, @model_repo})
      
      # Create serving pipeline for NLLB
      serving = Bumblebee.Text.translation(model_info, tokenizer, generation_config)
      
      Logger.info("Translation model loaded successfully")
      
      {:ok, %{serving: serving, model: model_info, tokenizer: tokenizer}}
    rescue
      e ->
        error_message = "Failed to load translation model: #{Exception.message(e)}"
        Logger.error(error_message)
        {:error, error_message}
    end
  end

  defp convert_to_nllb_lang_code(lang_code) do
    # Convert ISO 639-1 codes to NLLB language codes
    case lang_code do
      "es" -> "spa_Latn"
      "fr" -> "fra_Latn"
      "de" -> "deu_Latn"
      "pt" -> "por_Latn"
      "it" -> "ita_Latn"
      "ja" -> "jpn_Jpan"
      "zh" -> "zho_Hans"
      "ko" -> "kor_Hang"
      "ru" -> "rus_Cyrl"
      "ar" -> "arb_Arab"
      _ -> "spa_Latn"  # Default to Spanish if unknown
    end
  end

  defp translate_string(text, target_lang, %{serving: serving}) do
    # Convert language code to NLLB format
    src_lang = "eng_Latn"  # English source
    tgt_lang = convert_to_nllb_lang_code(target_lang)
    
    input = %{text: text, source_language_token: src_lang, target_language_token: tgt_lang}
    
    try do
      %{results: [%{text: translation}]} = Nx.Serving.run(serving, input)
      
      # Clean up the translation
      String.trim(translation)
    rescue
      e ->
        Logger.error("Translation failed for '#{text}': #{Exception.message(e)}")
        text  # Return original string if translation fails
    end
  end


  def supported_languages, do: @supported_languages
end