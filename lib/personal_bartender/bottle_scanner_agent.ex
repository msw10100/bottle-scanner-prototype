defmodule PersonalBartender.BottleScannerAgent do
  @moduledoc """
  Chorus agent for intelligent bottle recognition and collection management.
  
  This agent uses LLM vision capabilities to identify liquor bottles and 
  learns from user corrections to improve accuracy over time.
  """
  
  use Chorus.Agent
  import Chorus.Agent.SemanticMemoryHelpers
  alias PersonalBartender.VisionAPI
  alias PersonalBartender.BottleScanner
  
  agent do
    name "bottle-scanner"
    role """
    Expert bottle recognition specialist. I analyze photos of liquor bottles to identify:
    - Brand names and product lines
    - Spirit types (whiskey, vodka, gin, etc.)
    - Alcohol proof/ABV when visible
    - Bottle sizes and special editions
    - Multiple bottles in collection photos
    
    I learn from corrections to improve my accuracy over time.
    """
    
    semantic_memory do
      enabled true
      auto_store true
      search_type :hybrid
    end
    
    init_agent_state(%{
      scanned_bottles: [],
      corrections_received: 0,
      accuracy_improvements: []
    })
  end
  
  handle %{type: "scan_bottle", image_path: image_path} do
    case scan_local_image(image_path) do
      {:ok, result} ->
        new_state = %{agent_state | 
          scanned_bottles: [result | agent_state.scanned_bottles]
        }
        
        # Remember this scan for learning
        remember_content(%{}, "Scanned bottle: #{result["brand"]} #{result["type"]} (confidence: #{result["confidence"]})")
        
        {:ok, result, new_state}
        
      {:error, reason} ->
        {:error, "Scanning failed: #{reason}"}
    end
  end
  
  handle %{type: "scan_bottle", image_url: image_url} do
    case BottleScanner.analyze_bottle(image_url) do
      {:ok, result} ->
        new_state = %{agent_state | 
          scanned_bottles: [result | agent_state.scanned_bottles]
        }
        
        remember_content(%{}, "Scanned bottle from URL: #{result["brand"]} #{result["type"]}")
        
        {:ok, result, new_state}
        
      {:error, reason} ->
        {:error, "URL scanning failed: #{reason}"}
    end
  end
  
  handle %{type: "scan_multiple", image_path: image_path} do
    case scan_multiple_local(image_path) do
      {:ok, results} ->
        new_bottles = results.bottles
        new_state = %{agent_state | 
          scanned_bottles: new_bottles ++ agent_state.scanned_bottles
        }
        
        remember_content(%{}, "Scanned #{length(new_bottles)} bottles from collection photo")
        
        {:ok, results, new_state}
        
      {:error, reason} ->
        {:error, "Multi-bottle scanning failed: #{reason}"}
    end
  end
  
  handle %{type: "correct_identification", original_result: original, correction: correction} do
    # Learn from user correction
    learning_data = """
    User correction received:
    My identification: #{original.brand} #{original.type} (confidence: #{original.confidence})
    Actual bottle: #{correction.brand} #{correction.type}
    User notes: #{correction.notes || "No additional notes"}
    
    Key learning points:
    - Look for: #{correction.distinguishing_features || "user will provide features"}
    - Avoid confusing with: #{original.brand} #{original.type}
    """
    
    remember_content(%{}, learning_data, metadata: %{
      type: "user_correction", 
      importance: "high",
      original_confidence: original.confidence
    })
    
    new_state = %{agent_state | 
      corrections_received: agent_state.corrections_received + 1,
      accuracy_improvements: [correction | agent_state.accuracy_improvements]
    }
    
    {:ok, "Thank you for the correction! I've learned that this bottle is actually #{correction.brand} #{correction.type}. I'll remember this for future scans.", new_state}
  end
  
  handle %{type: "get_stats"} do
    stats = %{
      total_scanned: length(agent_state.scanned_bottles),
      corrections_received: agent_state.corrections_received,
      recent_scans: Enum.take(agent_state.scanned_bottles, 5),
      learning_rate: calculate_learning_rate(agent_state)
    }
    
    {:ok, stats, agent_state}
  end
  
  handle %{type: "search_knowledge", query: query} do
    # Search accumulated knowledge about bottles
    case recall_content(%{}, query, limit: 5) do
      {:ok, memories} when length(memories) > 0 ->
        knowledge = Enum.map(memories, fn memory ->
          %{
            content: memory.content,
            relevance: memory.similarity || 0.0,
            timestamp: memory.inserted_at
          }
        end)
        
        {:ok, %{query: query, knowledge: knowledge}, agent_state}
        
      {:ok, []} ->
        {:ok, %{query: query, knowledge: [], message: "No knowledge found for: #{query}"}, agent_state}
    end
  end
  
  handle %{type: "compare_providers", image_path: image_path} do
    case prepare_image_for_comparison(image_path) do
      {:ok, data_url} ->
        case VisionAPI.compare_providers(data_url) do
          {:ok, results} ->
            # Store comparison results for learning
            comparison_summary = create_comparison_summary(results)
            remember_content(%{}, comparison_summary, metadata: %{
              type: "provider_comparison",
              importance: "medium",
              image_path: image_path
            })
            
            {:ok, %{
              image_path: image_path,
              comparison_results: results,
              summary: analyze_comparison_results(results)
            }, agent_state}
            
          {:error, reason} ->
            {:error, "Provider comparison failed: #{reason}"}
        end
        
      {:error, reason} ->
        {:error, "Failed to prepare image: #{reason}"}
    end
  end
  
  handle_any do
    {:ok, "I specialize in bottle recognition. Try: scan_bottle, scan_multiple, correct_identification, get_stats, search_knowledge, or compare_providers. You sent: #{inspect(message)}", agent_state}
  end
  
  defp scan_local_image(image_path) do
    full_path = Path.join([Application.app_dir(:personal_bartender), "priv", "data", "images", image_path])
    
    case File.exists?(full_path) do
      true ->
        # Pass the full file path directly to VisionAPI for processing and optimization
        VisionAPI.analyze_bottle_image(full_path)
        
      false ->
        {:error, "Image file not found: #{image_path}. Place images in priv/data/images/"}
    end
  end
  
  defp scan_multiple_local(image_path) do
    full_path = Path.join([Application.app_dir(:personal_bartender), "priv", "data", "images", image_path])
    
    case File.exists?(full_path) do
      true ->
        # Pass the full file path directly to VisionAPI for processing and optimization
        VisionAPI.analyze_multiple_bottles(full_path)
        
      false ->
        {:error, "Image file not found: #{image_path}"}
    end
  end
  
  defp get_mime_type(filename) do
    case Path.extname(filename) |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      _ -> "image/jpeg"  # default
    end
  end
  
  defp calculate_learning_rate(state) do
    total_scans = length(state.scanned_bottles)
    corrections = state.corrections_received
    
    if total_scans > 0 do
      correction_rate = corrections / total_scans
      learning_score = min(corrections * 10, 100)  # Each correction improves learning
      
      %{
        correction_rate: Float.round(correction_rate, 3),
        learning_score: learning_score,
        status: get_learning_status(learning_score)
      }
    else
      %{
        correction_rate: 0.0,
        learning_score: 0,
        status: "No scans yet"
      }
    end
  end
  
  defp get_learning_status(score) when score >= 50, do: "Advanced"
  defp get_learning_status(score) when score >= 20, do: "Learning" 
  defp get_learning_status(_), do: "Beginner"
  
  defp prepare_image_for_comparison(image_path) do
    full_path = Path.join([Application.app_dir(:personal_bartender), "priv", "data", "images", image_path])
    
    case File.exists?(full_path) do
      true ->
        # Use ImageUtils to create an optimized data URL for comparison
        case PersonalBartender.ImageUtils.create_optimized_data_url(full_path) do
          {:ok, data_url} ->
            {:ok, data_url}
            
          {:error, reason} ->
            {:error, "Failed to process image file: #{reason}"}
        end
        
      false ->
        {:error, "Image file not found: #{image_path}. Place images in priv/data/images/"}
    end
  end
  
  defp create_comparison_summary(results) do
    successful_results = 
      results
      |> Enum.filter(fn {_provider, data} -> 
        match?({:ok, _}, data.result)
      end)
      |> Enum.map(fn {provider, data} -> 
        {:ok, parsed_result} = data.result
        {provider, parsed_result, data.duration_ms, data.estimated_cost}
      end)
    
    if length(successful_results) > 0 do
      """
      Provider Comparison Results:
      #{Enum.map(successful_results, fn {provider, result, duration, cost} ->
        "- #{provider |> Atom.to_string() |> String.upcase()}: #{result["brand"]} #{result["type"]} (confidence: #{result["confidence"]}, #{duration}ms, $#{Float.round(cost.total, 4)})"
      end) |> Enum.join("\n")}
      
      Analysis: #{analyze_agreement(successful_results)}
      """
    else
      "Provider comparison failed - no successful results from any provider."
    end
  end
  
  defp analyze_comparison_results(results) do
    successful_results = 
      results
      |> Enum.filter(fn {_provider, data} -> 
        match?({:ok, _}, data.result)
      end)
      |> Enum.map(fn {provider, data} -> 
        {:ok, parsed_result} = data.result
        {provider, parsed_result, data.duration_ms, data.estimated_cost, data.model_info}
      end)
    
    if length(successful_results) == 0 do
      %{
        status: "all_failed",
        message: "All providers failed to analyze the image",
        recommendations: ["Check image quality", "Verify API keys", "Try simpler image"]
      }
    else
      brands = Enum.map(successful_results, fn {_provider, result, _duration, _cost, _info} -> result["brand"] end)
      types = Enum.map(successful_results, fn {_provider, result, _duration, _cost, _info} -> result["type"] end)
      
      brand_agreement = calculate_agreement(brands)
      type_agreement = calculate_agreement(types)
      
      fastest_provider = Enum.min_by(successful_results, fn {_provider, _result, duration, _cost, _info} -> duration end)
      cheapest_provider = Enum.min_by(successful_results, fn {_provider, _result, _duration, cost, _info} -> cost.total end)
      highest_confidence = Enum.max_by(successful_results, fn {_provider, result, _duration, _cost, _info} -> result["confidence"] || 0.0 end)
      
      {fastest_name, _fastest_result, fastest_time, _fastest_cost, _fastest_info} = fastest_provider
      {cheapest_name, _cheapest_result, _cheapest_duration, cheapest_cost, _cheapest_info} = cheapest_provider
      {best_name, best_result, _best_duration, _best_cost, _best_info} = highest_confidence
      
      %{
        status: "success",
        provider_count: length(successful_results),
        brand_agreement: brand_agreement,
        type_agreement: type_agreement,
        fastest: %{provider: fastest_name, time_ms: fastest_time},
        cheapest: %{provider: cheapest_name, cost: cheapest_cost.total},
        highest_confidence: %{provider: best_name, confidence: best_result["confidence"], result: best_result},
        recommendation: determine_best_provider(successful_results),
        total_cost: Enum.sum(Enum.map(successful_results, fn {_p, _r, _d, cost, _i} -> cost.total end))
      }
    end
  end
  
  defp analyze_agreement(successful_results) do
    if length(successful_results) < 2 do
      "Only one provider succeeded - cannot analyze agreement."
    else
      brands = Enum.map(successful_results, fn {_provider, result, _duration, _cost} -> result["brand"] end)
      types = Enum.map(successful_results, fn {_provider, result, _duration, _cost} -> result["type"] end)
      
      brand_agreement = calculate_agreement(brands)
      type_agreement = calculate_agreement(types)
      
      cond do
        brand_agreement >= 0.8 and type_agreement >= 0.8 ->
          "High agreement between providers - results are likely accurate."
        brand_agreement >= 0.6 or type_agreement >= 0.6 ->
          "Moderate agreement between providers - results need verification."
        true ->
          "Low agreement between providers - image may be unclear or bottles difficult to identify."
      end
    end
  end
  
  defp calculate_agreement(values) do
    if length(values) <= 1 do
      1.0
    else
      # Calculate percentage of values that match the most common value
      most_common = Enum.frequencies(values) |> Enum.max_by(fn {_value, count} -> count end) |> elem(1)
      most_common / length(values)
    end
  end
  
  defp determine_best_provider(successful_results) do
    # Simple scoring: balance accuracy, speed, and cost
    scored_results = 
      Enum.map(successful_results, fn {provider, result, duration, cost, model_info} ->
        confidence_score = (result["confidence"] || 0.5) * 40  # 0-40 points
        speed_score = max(0, 30 - (duration / 1000))  # 0-30 points, penalty for slow
        cost_score = max(0, 30 - (cost.total * 10000))  # 0-30 points, penalty for expensive
        
        total_score = confidence_score + speed_score + cost_score
        
        {provider, total_score, %{
          confidence: result["confidence"] || 0.0,
          duration: duration,
          cost: cost.total,
          model: model_info.name
        }}
      end)
    
    {best_provider, best_score, stats} = Enum.max_by(scored_results, fn {_provider, score, _stats} -> score end)
    
    %{
      provider: best_provider,
      score: Float.round(best_score, 1),
      reason: "Best balance of accuracy (#{Float.round(stats.confidence, 2)}), speed (#{stats.duration}ms), and cost ($#{Float.round(stats.cost, 4)})",
      model: stats.model
    }
  end
end