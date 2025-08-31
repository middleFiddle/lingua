defmodule Lingua.ModelDownloader do
  @moduledoc """
  Downloads and caches ML models for translation.
  
  Models are downloaded once and cached locally for reuse.
  Supports downloading from HuggingFace Hub.
  """

  require Logger

  # Import model constants from Translator
  @model_name "nllb-200-distilled-600M"
  @model_repo "facebook/nllb-200-distilled-600M"
  
  @model_configs %{
    @model_name => %{
      repo: @model_repo,
      description: "Facebook NLLB translation model (200 languages)",
      size_mb: 1200
    }
  }

  def download(_opts \\ []) do
    Logger.info("Setting up Lingua translation models...")
    
    # Create models directory
    models_dir = get_models_directory()
    File.mkdir_p!(models_dir)
    
    # Download each required model
    for {model_name, config} <- @model_configs do
      download_model(model_name, config, models_dir)
    end
    
    Logger.info("Model setup complete!")
    Logger.info("Models cached in: #{models_dir}")
  end

  defp download_model(model_name, config, models_dir) do
    model_path = Path.join(models_dir, model_name)
    
    if File.exists?(model_path) do
      Logger.info("Model #{model_name} already cached at #{model_path}")
    else
      Logger.info("Downloading #{config.description} (~#{config.size_mb}MB)")
      Logger.info("This may take several minutes on first run...")
      
      # Create model directory
      File.mkdir_p!(model_path)
      
      # Download model using Bumblebee
      try do
        {:ok, _model_info} = Bumblebee.load_model({:hf, config.repo})
        {:ok, _tokenizer} = Bumblebee.load_tokenizer({:hf, config.repo})
        
        # Create a simple manifest file to track what's downloaded
        manifest = %{
          model_name: model_name,
          repo: config.repo,
          downloaded_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          lingua_version: Lingua.version()
        }
        
        manifest_path = Path.join(model_path, "lingua_manifest.json")
        File.write!(manifest_path, Jason.encode!(manifest, pretty: true))
        
        Logger.info("Successfully downloaded #{model_name}")
      rescue
        e ->
          Logger.error("Failed to download #{model_name}: #{Exception.message(e)}")
          
          # Clean up partial download
          if File.exists?(model_path) do
            File.rm_rf!(model_path)
          end
          
          System.halt(1)
      end
    end
  end

  def get_models_directory do
    # Try different locations for model caching
    cond do
      # User-specific cache directory (preferred)
      home = System.get_env("HOME") ->
        Path.join(home, ".lingua/models")
      
      # Application-specific directory 
      app_dir = Application.app_dir(:lingua) ->
        Path.join(app_dir, "priv/models")
      
      # Fallback to tmp directory
      true ->
        Path.join(System.tmp_dir!(), "lingua_models")
    end
  end

  def list_models do
    models_dir = get_models_directory()
    
    if File.exists?(models_dir) do
      models_dir
      |> File.ls!()
      |> Enum.filter(fn item ->
        model_path = Path.join(models_dir, item)
        File.dir?(model_path) and File.exists?(Path.join(model_path, "lingua_manifest.json"))
      end)
      |> Enum.map(fn model_name ->
        manifest_path = Path.join([models_dir, model_name, "lingua_manifest.json"])
        
        manifest = 
          manifest_path
          |> File.read!()
          |> Jason.decode!()
        
        %{
          name: model_name,
          repo: manifest["repo"],
          downloaded_at: manifest["downloaded_at"],
          path: Path.join(models_dir, model_name)
        }
      end)
    else
      []
    end
  end

  def model_exists?(model_name) do
    models_dir = get_models_directory()
    model_path = Path.join(models_dir, model_name)
    manifest_path = Path.join(model_path, "lingua_manifest.json")
    
    File.exists?(manifest_path)
  end

  def clean_models do
    models_dir = get_models_directory()
    
    if File.exists?(models_dir) do
      Logger.info("Cleaning model cache at #{models_dir}")
      File.rm_rf!(models_dir)
      Logger.info("Model cache cleaned")
    else
      Logger.info("No model cache found")
    end
  end

  def cache_info do
    models_dir = get_models_directory()
    models = list_models()
    
    total_size = 
      if File.exists?(models_dir) do
        calculate_directory_size(models_dir)
      else
        0
      end
    
    %{
      cache_directory: models_dir,
      models_count: length(models),
      total_size_mb: div(total_size, 1024 * 1024),
      models: models
    }
  end

  defp calculate_directory_size(dir) do
    try do
      dir
      |> File.ls!()
      |> Enum.reduce(0, fn item, acc ->
        path = Path.join(dir, item)
        
        cond do
          File.regular?(path) ->
            acc + File.stat!(path).size
          
          File.dir?(path) ->
            acc + calculate_directory_size(path)
          
          true ->
            acc
        end
      end)
    rescue
      e ->
        Logger.warning("Failed to calculate directory size for #{dir}: #{Exception.message(e)}")
        0
    end
  end
end