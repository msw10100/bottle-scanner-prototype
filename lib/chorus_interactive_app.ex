defmodule PersonalBartender do
  @moduledoc """
  Personal Bartender - AI-powered bottle recognition and cocktail recommendations.
  
  This application demonstrates bottle recognition using LLM vision capabilities
  and provides personalized cocktail recommendations based on your collection.
  """
  
  alias PersonalBartender.BottleScanner
  alias PersonalBartender.CocktailRecommender
  
  @doc """
  Start the bottle scanner agent for persistent, learning-based recognition.
  
  ## Examples
  
      iex> PersonalBartender.start_agent()
      {:ok, #PID<0.123.0>}
  """
  def start_agent do
    Chorus.Runtime.summon(PersonalBartender.BottleScannerAgent, name: "personal-bartender")
  end
  
  @doc """
  Scan a bottle image using the Chorus agent (recommended for learning).
  
  ## Examples
  
      # Scan local image (place in priv/data/images/)
      iex> PersonalBartender.scan_with_agent("my_bottle.jpg")
      {:ok, %{brand: "Jack Daniel's", type: "Tennessee Whiskey", confidence: 0.95}}
      
      # Scan from URL
      iex> PersonalBartender.scan_with_agent("https://example.com/bottle.jpg", :url)
      {:ok, %{brand: "Grey Goose", type: "Vodka", confidence: 0.90}}
  """
  def scan_with_agent(image_path_or_url, type \\ :local) do
    case ensure_agent_running() do
      {:ok, agent_pid} ->
        case type do
          :local ->
            Chorus.Runtime.perform(agent_pid, %{type: "scan_bottle", image_path: image_path_or_url})
          :url ->
            Chorus.Runtime.perform(agent_pid, %{type: "scan_bottle", image_url: image_path_or_url})
        end
        
      {:error, reason} ->
        {:error, "Agent not available: #{reason}"}
    end
  end
  
  @doc """
  Scan multiple bottles in one image using the agent.
  """
  def scan_multiple_with_agent(image_path) do
    case ensure_agent_running() do
      {:ok, agent_pid} ->
        Chorus.Runtime.perform(agent_pid, %{type: "scan_multiple", image_path: image_path})
        
      {:error, reason} ->
        {:error, "Agent not available: #{reason}"}
    end
  end
  
  @doc """
  Correct a bottle identification to help the agent learn.
  
  ## Examples
  
      iex> original = %{brand: "Unknown", type: "Whiskey", confidence: 0.3}
      iex> correction = %{brand: "Maker's Mark", type: "Bourbon Whiskey", notes: "Red wax seal"}
      iex> PersonalBartender.correct_identification(original, correction)
      {:ok, "Thank you for the correction! I've learned..."}
  """
  def correct_identification(original_result, correction) do
    case ensure_agent_running() do
      {:ok, agent_pid} ->
        Chorus.Runtime.perform(agent_pid, %{
          type: "correct_identification",
          original_result: original_result,
          correction: correction
        })
        
      {:error, reason} ->
        {:error, "Agent not available: #{reason}"}
    end
  end
  
  @doc """
  Get agent statistics and learning progress.
  """
  def get_agent_stats do
    case ensure_agent_running() do
      {:ok, agent_pid} ->
        Chorus.Runtime.perform(agent_pid, %{type: "get_stats"})
        
      {:error, reason} ->
        {:error, "Agent not available: #{reason}"}
    end
  end
  
  @doc """
  Search the agent's accumulated knowledge about bottles.
  """
  def search_bottle_knowledge(query) do
    case ensure_agent_running() do
      {:ok, agent_pid} ->
        Chorus.Runtime.perform(agent_pid, %{type: "search_knowledge", query: query})
        
      {:error, reason} ->
        {:error, "Agent not available: #{reason}"}
    end
  end
  
  @doc """
  Compare results from multiple LLM providers for the same bottle image.
  
  ## Examples
  
      iex> PersonalBartender.compare_providers("my_bottle.jpg")
      {:ok, %{comparison_results: %{openai: %{result: {...}, duration_ms: 2500, estimated_cost: %{total: 0.012}}}}}
  """
  def compare_providers(image_path) do
    case ensure_agent_running() do
      {:ok, agent_pid} ->
        Chorus.Runtime.perform(agent_pid, %{type: "compare_providers", image_path: image_path})
        
      {:error, reason} ->
        {:error, "Agent not available: #{reason}"}
    end
  end
  
  @doc """
  Test bottle recognition with an image URL (direct API call, no learning).
  
  ## Examples
  
      iex> PersonalBartender.scan_bottle("https://example.com/bottle.jpg")
      {:ok, %{brand: "Jack Daniel's", type: "Tennessee Whiskey", confidence: 0.95}}
  """
  def scan_bottle(image_url) do
    BottleScanner.analyze_bottle(image_url)
  end
  
  @doc """
  Get cocktail recommendations based on available bottles.
  
  ## Examples
  
      iex> PersonalBartender.recommend_cocktails(["whiskey", "sweet vermouth", "bitters"])
      {:ok, [%{name: "Manhattan"}, %{name: "Old Fashioned"}]}
  """
  def recommend_cocktails(available_spirits) do
    CocktailRecommender.suggest_cocktails(available_spirits)
  end
  
  @doc """
  Interactive bottle scanning session - processes multiple images.
  """
  def start_scanning_session do
    IO.puts("🍸 Personal Bartender - Bottle Recognition Test")
    IO.puts("Choose scanning mode:")
    IO.puts("1. Local files (place images in priv/data/images/)")
    IO.puts("2. URLs")
    
    mode = case IO.gets("Enter choice (1 or 2): ") |> String.trim() do
      "1" -> :local
      "2" -> :url
      _ -> :local
    end
    
    IO.puts("Enter image #{if mode == :local, do: "filenames", else: "URLs"} (type 'done' to finish):")
    
    scan_loop([], mode)
  end
  
  @doc """
  Start an interactive cocktail recommendation session.
  """
  def start_cocktail_session do
    CocktailRecommender.start_recommendation_session()
  end
  
  @doc """
  List images available in the local images directory.
  """
  def list_available_images do
    images_path = Path.join([Application.app_dir(:personal_bartender), "priv", "data", "images"])
    
    case File.ls(images_path) do
      {:ok, files} ->
        image_files = Enum.filter(files, fn file ->
          String.downcase(Path.extname(file)) in [".jpg", ".jpeg", ".png", ".gif", ".webp"]
        end)
        
        if length(image_files) > 0 do
          IO.puts("📁 Available images in priv/data/images/:")
          Enum.each(image_files, fn file ->
            IO.puts("  • #{file}")
          end)
          {:ok, image_files}
        else
          IO.puts("📁 No images found in priv/data/images/")
          IO.puts("Drop some bottle images there to test!")
          {:ok, []}
        end
        
      {:error, :enoent} ->
        IO.puts("📁 Images directory not found. Creating it now...")
        File.mkdir_p!(images_path)
        {:ok, []}
        
      {:error, reason} ->
        {:error, "Failed to list images: #{reason}"}
    end
  end
  
  @doc """
  Quick test with a local image file.
  """
  def quick_test(image_filename) do
    IO.puts("🔍 Testing bottle recognition with #{image_filename}")
    
    case scan_with_agent(image_filename, :local) do
      {:ok, result} ->
        IO.puts("✅ Recognition Result:")
        IO.puts("   Brand: #{result.brand}")
        IO.puts("   Type: #{result.type}")
        IO.puts("   Proof: #{result.proof}")
        IO.puts("   Confidence: #{result.confidence}")
        if result.notes && result.notes != "" do
          IO.puts("   Notes: #{result.notes}")
        end
        result
        
      {:error, reason} ->
        IO.puts("❌ Recognition failed: #{reason}")
        {:error, reason}
    end
  end
  
  defp scan_loop(results, mode) do
    case IO.gets("> ") |> String.trim() do
      "done" -> 
        IO.puts("\n📊 Scanning Results:")
        Enum.each(results, fn {input, result} ->
          IO.puts("#{input}: #{inspect(result)}")
        end)
        results
        
      input when input != "" ->
        IO.puts("🔍 Analyzing: #{input}")
        result = case mode do
          :local -> scan_with_agent(input, :local)
          :url -> scan_with_agent(input, :url)
        end
        IO.puts("Result: #{inspect(result)}")
        scan_loop([{input, result} | results], mode)
        
      _ ->
        scan_loop(results, mode)
    end
  end
  
  defp ensure_agent_running do
    case Chorus.Runtime.find("personal-bartender") do
      {:ok, pid} -> {:ok, pid}
      {:error, :not_found} ->
        case start_agent() do
          {:ok, pid} -> {:ok, pid}
          {:error, reason} -> {:error, reason}
        end
    end
  end
end