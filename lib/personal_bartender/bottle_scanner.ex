defmodule PersonalBartender.BottleScanner do
  @moduledoc """
  Bottle recognition service using LLM vision capabilities.
  
  This module provides functionality to analyze bottle images and extract
  information about brand, type, proof, and other characteristics.
  """
  
  alias PersonalBartender.VisionAPI
  
  @doc """
  Analyze a bottle image and extract bottle information.
  
  ## Examples
  
      iex> PersonalBartender.BottleScanner.analyze_bottle("https://example.com/bottle.jpg")
      {:ok, %{brand: "Jack Daniel's", type: "Tennessee Whiskey", confidence: 0.95}}
  """
  def analyze_bottle(image_url) when is_binary(image_url) do
    case VisionAPI.analyze_bottle_image(image_url) do
      {:ok, result} -> 
        parsed_result = parse_vision_result(result)
        {:ok, parsed_result}
        
      {:error, reason} -> 
        {:error, "Vision analysis failed: #{reason}"}
    end
  end
  
  @doc """
  Analyze multiple bottles in a single image.
  """
  def analyze_multiple_bottles(image_url) when is_binary(image_url) do
    case VisionAPI.analyze_multiple_bottles(image_url) do
      {:ok, result} -> 
        bottles = Enum.map(result["bottles"] || [], &parse_bottle_data/1)
        {:ok, %{bottles: bottles, total_found: length(bottles)}}
        
      {:error, reason} -> 
        {:error, "Multi-bottle analysis failed: #{reason}"}
    end
  end
  
  @doc """
  Test bottle recognition with a predefined set of test images.
  """
  def run_recognition_tests do
    test_images = [
      "https://images.unsplash.com/photo-1566836584219-23a9a4ac5d25", # Jack Daniel's
      "https://images.unsplash.com/photo-1536939459926-301728717817", # Whiskey bottles
      "https://images.unsplash.com/photo-1564149504476-5b7a45fd32c6"  # Gin bottle
    ]
    
    IO.puts("🧪 Running bottle recognition tests...")
    
    results = Enum.map(test_images, fn image_url ->
      IO.puts("📸 Testing: #{image_url}")
      
      case analyze_bottle(image_url) do
        {:ok, result} -> 
          IO.puts("✅ Success: #{inspect(result)}")
          {image_url, :success, result}
          
        {:error, reason} -> 
          IO.puts("❌ Failed: #{reason}")
          {image_url, :error, reason}
      end
    end)
    
    success_count = Enum.count(results, fn {_, status, _} -> status == :success end)
    IO.puts("\n📊 Results: #{success_count}/#{length(test_images)} successful")
    
    results
  end
  
  defp parse_vision_result(result) when is_map(result) do
    %{
      brand: get_in(result, ["brand"]) || "Unknown",
      type: get_in(result, ["type"]) || "Unknown Spirit",
      proof: get_in(result, ["proof"]) || "Unknown",
      size: get_in(result, ["size"]) || "Unknown",
      confidence: get_in(result, ["confidence"]) || 0.0,
      notes: get_in(result, ["notes"]) || ""
    }
  end
  
  defp parse_vision_result(result) when is_binary(result) do
    # Fallback for plain text responses
    %{
      brand: "Unknown",
      type: "Unknown Spirit", 
      proof: "Unknown",
      size: "Unknown",
      confidence: 0.5,
      notes: result
    }
  end
  
  defp parse_bottle_data(bottle_data) when is_map(bottle_data) do
    %{
      brand: bottle_data["brand"] || "Unknown",
      type: bottle_data["type"] || "Unknown",
      proof: bottle_data["proof"] || "Unknown", 
      confidence: bottle_data["confidence"] || 0.0,
      position: bottle_data["position"] || 0
    }
  end
end