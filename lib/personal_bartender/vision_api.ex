defmodule PersonalBartender.VisionAPI do
  @moduledoc """
  Interface to various LLM vision APIs for bottle recognition.
  
  This module provides adapters for different vision APIs including
  OpenAI GPT-4V, Google Gemini Vision, and others.
  """
  
  require Logger
  alias PersonalBartender.ImageUtils
  
  @openai_vision_url "https://api.openai.com/v1/chat/completions"
  @gemini_vision_url "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
  @claude_vision_url "https://api.anthropic.com/v1/messages"
  @openrouter_vision_url "https://openrouter.ai/api/v1/chat/completions"
  
  @doc """
  Analyze a bottle image using the configured vision provider.
  """
  def analyze_bottle_image(image_url) do
    provider = get_vision_provider()
    
    case provider do
      :openai -> analyze_with_openai(image_url, single_bottle_prompt())
      :gemini -> analyze_with_gemini(image_url, single_bottle_prompt())
      :claude -> analyze_with_claude(image_url, single_bottle_prompt())
      :openrouter -> analyze_with_openrouter(image_url, single_bottle_prompt())
      :test -> test_response()  # For testing without API calls
    end
  end
  
  @doc """
  Analyze multiple bottles in a single image.
  """
  def analyze_multiple_bottles(image_url) do
    provider = get_vision_provider()
    
    case provider do
      :openai -> analyze_with_openai(image_url, multiple_bottles_prompt())
      :gemini -> analyze_with_gemini(image_url, multiple_bottles_prompt())
      :claude -> analyze_with_claude(image_url, multiple_bottles_prompt())
      :openrouter -> analyze_with_openrouter(image_url, multiple_bottles_prompt())
      :test -> test_multiple_response()
    end
  end

  @doc """
  Compare results from multiple LLM providers for the same image.
  Expects a data URL (data:image/jpeg;base64,...) or HTTP URL.
  Returns a map with results from each available provider.
  """
  def compare_providers(image_data_url, prompt \\ nil) do
    prompt_to_use = prompt || single_bottle_prompt()
    providers = [:openai, :gemini, :claude, :openrouter, :test]
    
    results = %{}
    
    # Test each provider and collect results with cost estimates
    results = 
      Enum.reduce(providers, results, fn provider, acc ->
        start_time = System.monotonic_time(:millisecond)
        
        result = case provider do
          :openai -> 
            if get_openai_api_key(), do: analyze_with_openai(image_data_url, prompt_to_use), else: {:error, "No API key"}
          :gemini -> 
            if get_gemini_api_key(), do: analyze_with_gemini(image_data_url, prompt_to_use), else: {:error, "No API key"}
          :claude -> 
            if get_claude_api_key(), do: analyze_with_claude(image_data_url, prompt_to_use), else: {:error, "No API key"}
          :openrouter -> 
            if get_openrouter_api_key(), do: analyze_with_openrouter(image_data_url, prompt_to_use), else: {:error, "No API key"}
          :test -> 
            test_response()
        end
        
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        
        provider_result = %{
          result: result,
          duration_ms: duration,
          timestamp: DateTime.utc_now(),
          estimated_cost: estimate_cost(provider, image_data_url, prompt_to_use),
          model_info: get_model_info(provider)
        }
        
        Map.put(acc, provider, provider_result)
      end)
    
    {:ok, results}
  end
  
  # OpenAI GPT-4 Vision implementation
  defp analyze_with_openai(image_url, prompt) do
    api_key = get_openai_api_key()
    
    if api_key do
      payload = %{
        model: "gpt-4o",
        messages: [
          %{
            role: "user",
            content: [
              %{type: "text", text: prompt},
              %{type: "image_url", image_url: %{url: image_url, detail: "high"}}
            ]
          }
        ],
        max_tokens: 500,
        temperature: 0.1
      }
      
      headers = [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"}
      ]
      
      case HTTPoison.post(@openai_vision_url, Jason.encode!(payload), headers, timeout: 60_000) do
        {:ok, %{status_code: 200, body: body}} ->
          response = Jason.decode!(body)
          content = get_in(response, ["choices", Access.at(0), "message", "content"])
          parse_json_response(content)
          
        {:ok, %{status_code: status_code, body: body}} ->
          Logger.error("OpenAI API error: #{status_code} - #{body}")
          {:error, "API returned status #{status_code}"}
          
        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("HTTP request failed: #{inspect(reason)}")
          {:error, "Network error: #{reason}"}
      end
    else
      {:error, "OpenAI API key not configured. Set OPENAI_API_KEY environment variable."}
    end
  end
  
  # Claude 3.5 Sonnet Vision implementation
  defp analyze_with_claude(image_url, prompt) do
    api_key = get_claude_api_key()
    
    if api_key do
      # Download image to base64 (Claude requires base64)
      case download_and_encode_image(image_url) do
        {:ok, base64_data} ->
          # Determine media type from image data
          media_type = get_image_media_type(image_url)
          
          payload = %{
            model: "claude-3-5-sonnet-20241022",
            max_tokens: 500,
            messages: [
              %{
                role: "user",
                content: [
                  %{
                    type: "image",
                    source: %{
                      type: "base64",
                      media_type: media_type,
                      data: base64_data
                    }
                  },
                  %{
                    type: "text",
                    text: prompt
                  }
                ]
              }
            ]
          }
          
          headers = [
            {"x-api-key", api_key},
            {"Content-Type", "application/json"},
            {"anthropic-version", "2023-06-01"}
          ]
          
          case HTTPoison.post(@claude_vision_url, Jason.encode!(payload), headers, timeout: 60_000) do
            {:ok, %{status_code: 200, body: body}} ->
              response = Jason.decode!(body)
              content = get_in(response, ["content", Access.at(0), "text"])
              parse_json_response(content)
              
            {:ok, %{status_code: status_code, body: body}} ->
              Logger.error("Claude API error: #{status_code} - #{body}")
              {:error, "Claude API returned status #{status_code}"}
              
            {:error, %HTTPoison.Error{reason: reason}} ->
              Logger.error("Claude HTTP request failed: #{inspect(reason)}")
              {:error, "Network error: #{reason}"}
          end
          
        {:error, reason} ->
          {:error, "Failed to process image for Claude: #{reason}"}
      end
    else
      {:error, "Claude API key not configured. Set ANTHROPIC_API_KEY environment variable."}
    end
  end
  
  # OpenRouter Vision implementation (OpenAI-compatible API)
  defp analyze_with_openrouter(image_url, prompt) do
    api_key = get_openrouter_api_key()
    
    if api_key do
      payload = %{
        model: "anthropic/claude-3.5-sonnet",  # Using Claude 3.5 Sonnet via OpenRouter
        messages: [
          %{
            role: "user",
            content: [
              %{type: "text", text: prompt},
              %{type: "image_url", image_url: %{url: image_url, detail: "high"}}
            ]
          }
        ],
        max_tokens: 500,
        temperature: 0.1
      }
      
      headers = [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"},
        {"HTTP-Referer", "https://github.com/anthropics/claude-code"},  # Optional: for analytics
        {"X-Title", "Personal Bartender"}  # Optional: for analytics
      ]
      
      case HTTPoison.post(@openrouter_vision_url, Jason.encode!(payload), headers, timeout: 60_000) do
        {:ok, %{status_code: 200, body: body}} ->
          response = Jason.decode!(body)
          content = get_in(response, ["choices", Access.at(0), "message", "content"])
          parse_json_response(content)
          
        {:ok, %{status_code: status_code, body: body}} ->
          Logger.error("OpenRouter API error: #{status_code} - #{body}")
          {:error, "OpenRouter API returned status #{status_code}"}
          
        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("OpenRouter HTTP request failed: #{inspect(reason)}")
          {:error, "Network error: #{reason}"}
      end
    else
      {:error, "OpenRouter API key not configured. Set OPENROUTER_API_KEY environment variable."}
    end
  end

  # Google Gemini Vision implementation 
  defp analyze_with_gemini(image_url, prompt) do
    api_key = get_gemini_api_key()
    
    if api_key do
      # Download image to base64 (Gemini requires base64)
      case download_and_encode_image(image_url) do
        {:ok, base64_data} ->
          payload = %{
            contents: [
              %{
                parts: [
                  %{text: prompt},
                  %{
                    inline_data: %{
                      mime_type: "image/jpeg",
                      data: base64_data
                    }
                  }
                ]
              }
            ],
            generationConfig: %{
              temperature: 0.1,
              maxOutputTokens: 500
            }
          }
          
          url = "#{@gemini_vision_url}?key=#{api_key}"
          headers = [{"Content-Type", "application/json"}]
          
          case HTTPoison.post(url, Jason.encode!(payload), headers, timeout: 60_000) do
            {:ok, %{status_code: 200, body: body}} ->
              response = Jason.decode!(body)
              content = get_in(response, ["candidates", Access.at(0), "content", "parts", Access.at(0), "text"])
              parse_json_response(content)
              
            {:error, reason} ->
              Logger.error("Gemini API error: #{inspect(reason)}")
              {:error, "Gemini API failed"}
          end
          
        {:error, reason} ->
          {:error, "Failed to process image: #{reason}"}
      end
    else
      {:error, "Gemini API key not configured. Set GOOGLE_API_KEY environment variable."}
    end
  end
  
  # Test implementation for development
  defp test_response do
    {:ok, %{
      "brand" => "Jack Daniel's",
      "type" => "Tennessee Whiskey", 
      "proof" => "80",
      "size" => "750ml",
      "confidence" => 0.85,
      "notes" => "Test response - no actual vision analysis performed"
    }}
  end
  
  defp test_multiple_response do
    {:ok, %{
      "bottles" => [
        %{
          "brand" => "Jack Daniel's",
          "type" => "Tennessee Whiskey",
          "proof" => "80", 
          "confidence" => 0.9,
          "position" => 1
        },
        %{
          "brand" => "Grey Goose",
          "type" => "Vodka",
          "proof" => "80",
          "confidence" => 0.85,
          "position" => 2
        }
      ],
      "notes" => "Test response - 2 bottles detected"
    }}
  end
  
  defp single_bottle_prompt do
    """
    Analyze this liquor bottle image and identify the bottle. Return your response as a JSON object with these exact fields:

    {
      "brand": "brand name (e.g., 'Jack Daniel's', 'Grey Goose')",
      "type": "spirit type (e.g., 'Tennessee Whiskey', 'Vodka', 'Gin')", 
      "proof": "alcohol proof if visible (e.g., '80', '100')",
      "size": "bottle size if determinable (e.g., '750ml', '1L')",
      "confidence": 0.85,
      "notes": "any additional observations"
    }

    IMPORTANT: 
    - Return ONLY valid JSON, no other text
    - If you're unsure about any field, use "Unknown" as the value
    - Confidence should be between 0 and 1
    - Focus on accuracy over completeness
    """
  end
  
  defp multiple_bottles_prompt do
    """
    Analyze this image containing multiple liquor bottles. Identify each bottle from left to right and return a JSON object:

    {
      "bottles": [
        {
          "brand": "brand name",
          "type": "spirit type",
          "proof": "alcohol proof if visible", 
          "confidence": 0.85,
          "position": 1
        }
      ],
      "notes": "overall observations about the image"
    }

    IMPORTANT:
    - Return ONLY valid JSON, no other text
    - Position should be numbered left to right starting from 1
    - If you can't identify a bottle clearly, still include it with lower confidence
    - Focus on bottles that are clearly visible and identifiable
    """
  end
  
  defp parse_json_response(content) when is_binary(content) do
    # Try to extract JSON from the response
    cleaned_content = content
                     |> String.trim()
                     |> String.replace("```json", "")
                     |> String.replace("```", "")
                     |> String.trim()
    
    case Jason.decode(cleaned_content) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> 
        # Fallback: treat as plain text
        {:ok, %{
          "brand" => "Unknown",
          "type" => "Unknown",
          "confidence" => 0.3,
          "notes" => "Failed to parse JSON response: #{content}"
        }}
    end
  end
  
  defp download_and_encode_image(image_input) do
    cond do
      # If it's already a data URL, extract the base64 part
      String.starts_with?(image_input, "data:") ->
        case String.split(image_input, ",", parts: 2) do
          [_header, base64_data] -> {:ok, base64_data}
          _ -> {:error, "Invalid data URL format"}
        end
      
      # If it's an HTTP URL, download it and process
      String.starts_with?(image_input, "http") ->
        case HTTPoison.get(image_input, [], timeout: 30_000) do
          {:ok, %{status_code: 200, body: body}} ->
            # Save temporarily and process with ImageUtils
            temp_path = "/tmp/downloaded_image_#{System.unique_integer()}.jpg"
            
            case File.write(temp_path, body) do
              :ok ->
                case ImageUtils.create_optimized_data_url(temp_path) do
                  {:ok, data_url} ->
                    File.rm(temp_path)
                    # Extract base64 part from optimized data URL
                    case String.split(data_url, ",", parts: 2) do
                      [_header, base64_data] -> {:ok, base64_data}
                      _ -> {:error, "Failed to parse optimized data URL"}
                    end
                    
                  {:error, reason} ->
                    File.rm(temp_path)
                    {:error, "Failed to optimize downloaded image: #{reason}"}
                end
                
              {:error, reason} ->
                {:error, "Failed to save downloaded image: #{inspect(reason)}"}
            end
            
          {:error, reason} ->
            {:error, "Failed to download image: #{inspect(reason)}"}
        end
      
      # If it's a local file path, process it
      File.exists?(image_input) ->
        case ImageUtils.create_optimized_data_url(image_input) do
          {:ok, data_url} ->
            # Extract base64 part from optimized data URL
            case String.split(data_url, ",", parts: 2) do
              [_header, base64_data] -> {:ok, base64_data}
              _ -> {:error, "Failed to parse optimized data URL"}
            end
            
          {:error, reason} ->
            {:error, "Failed to optimize local image: #{reason}"}
        end
      
      # Invalid input
      true ->
        {:error, "Invalid image input: expected data URL, HTTP URL, or local file path"}
    end
  end
  
  defp get_vision_provider do
    case System.get_env("VISION_PROVIDER") do
      "gemini" -> :gemini
      "claude" -> :claude
      "openrouter" -> :openrouter
      "test" -> :test
      _ -> :openai  # default
    end
  end
  
  defp get_openai_api_key do
    System.get_env("OPENAI_API_KEY")
  end
  
  defp get_gemini_api_key do
    System.get_env("GOOGLE_API_KEY") || System.get_env("GEMINI_API_KEY")
  end
  
  defp get_claude_api_key do
    System.get_env("ANTHROPIC_API_KEY")
  end
  
  defp get_openrouter_api_key do
    System.get_env("OPENROUTER_API_KEY")
  end
  
  defp get_image_media_type(image_url) do
    cond do
      String.contains?(image_url, ".png") -> "image/png"
      String.contains?(image_url, ".gif") -> "image/gif"
      String.contains?(image_url, ".webp") -> "image/webp"
      true -> "image/jpeg"  # default
    end
  end
  
  # Cost estimation functions (approximate costs as of late 2024)
  defp estimate_cost(provider, image_url, prompt) do
    # Estimate image size in pixels (rough approximation)
    estimated_pixels = 1024 * 1024  # Assume 1MP images
    prompt_tokens = estimate_tokens(prompt)
    output_tokens = 150  # Estimated response length
    
    case provider do
      :openai -> 
        # GPT-4V: $0.01/1K tokens input, $0.03/1K tokens output, plus image cost
        image_cost = estimated_pixels / 1_000_000 * 0.00765  # $0.00765 per 1M pixels
        text_cost = (prompt_tokens / 1000 * 0.01) + (output_tokens / 1000 * 0.03)
        %{total: image_cost + text_cost, breakdown: %{image: image_cost, text: text_cost}, unit: "USD"}
        
      :gemini ->
        # Gemini Pro Vision: $0.0025/1K tokens, images free under 1000/day
        text_cost = (prompt_tokens + output_tokens) / 1000 * 0.0025
        %{total: text_cost, breakdown: %{image: 0.0, text: text_cost}, unit: "USD"}
        
      :claude ->
        # Claude 3.5 Sonnet: $3/MTok input, $15/MTok output, image cost varies by size
        image_cost = estimated_pixels / 1_000_000 * 0.0048  # ~$0.0048 per 1M pixels
        text_cost = (prompt_tokens / 1_000_000 * 3.0) + (output_tokens / 1_000_000 * 15.0)
        %{total: image_cost + text_cost, breakdown: %{image: image_cost, text: text_cost}, unit: "USD"}
        
      :openrouter ->
        # OpenRouter Claude 3.5 Sonnet: $3/MTok input, $15/MTok output (similar to direct Claude)
        # Adding small markup (~10%) for OpenRouter platform fee
        image_cost = estimated_pixels / 1_000_000 * 0.0053  # ~$0.0053 per 1M pixels (with markup)
        text_cost = (prompt_tokens / 1_000_000 * 3.3) + (output_tokens / 1_000_000 * 16.5)
        %{total: image_cost + text_cost, breakdown: %{image: image_cost, text: text_cost}, unit: "USD"}
        
      :test ->
        %{total: 0.0, breakdown: %{image: 0.0, text: 0.0}, unit: "USD"}
    end
  end
  
  defp estimate_tokens(text) do
    # Rough estimation: ~4 characters per token
    String.length(text) / 4
  end
  
  defp get_model_info(provider) do
    case provider do
      :openai -> %{
        name: "GPT-4 Vision Preview",
        strengths: ["Highest accuracy", "Best text recognition", "Excellent detail detection"],
        weaknesses: ["Most expensive", "Slower response times"],
        recommended_for: "High-accuracy production use"
      }
      :gemini -> %{
        name: "Gemini Pro Vision",
        strengths: ["Good accuracy", "Fast responses", "Cost-effective"],
        weaknesses: ["Requires image download", "Slightly lower accuracy"],
        recommended_for: "Balanced cost and performance"
      }
      :claude -> %{
        name: "Claude 3.5 Sonnet",
        strengths: ["Excellent reasoning", "Good accuracy", "Detailed analysis"],
        weaknesses: ["Moderate cost", "Requires image download"],
        recommended_for: "Detailed analysis and reasoning"
      }
      :openrouter -> %{
        name: "OpenRouter Claude 3.5 Sonnet",
        strengths: ["Multiple model access", "Good reasoning", "Platform flexibility", "Model redundancy"],
        weaknesses: ["Small markup cost", "Additional API layer", "Potential extra latency"],
        recommended_for: "Multi-model workflows and API resilience"
      }
      :test -> %{
        name: "Test Mode",
        strengths: ["Free", "Instant", "No API limits"],
        weaknesses: ["Mock data only", "No real analysis"],
        recommended_for: "Development and testing"
      }
    end
  end
end