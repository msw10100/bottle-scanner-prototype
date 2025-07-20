#!/usr/bin/env elixir

# Test script for multi-provider comparison with test mode
IO.puts("Testing multi-provider comparison with test mode...")

# Test the VisionAPI compare_providers functionality directly with test mode
IO.puts("\n=== Testing VisionAPI.compare_providers with test mode ===")

# Create a fake data URL for testing
fake_data_url = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAP/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAP/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/PwB8AAAGt/9k="

case PersonalBartender.VisionAPI.compare_providers(fake_data_url) do
  {:ok, results} ->
    IO.puts("Provider comparison succeeded!")
    IO.puts("\n=== COMPARISON RESULTS ===")
    
    Enum.each(results, fn {provider, data} ->
      IO.puts("\n--- #{String.upcase(to_string(provider))} ---")
      IO.puts("Duration: #{data.duration_ms}ms")
      IO.puts("Estimated cost: $#{Float.round(data.estimated_cost.total, 4)}")
      IO.puts("Model: #{data.model_info.name}")
      
      case data.result do
        {:ok, parsed_result} ->
          IO.puts("Result: SUCCESS")
          IO.puts("Brand: #{parsed_result["brand"]}")
          IO.puts("Type: #{parsed_result["type"]}")
          IO.puts("Confidence: #{parsed_result["confidence"]}")
          IO.puts("Notes: #{parsed_result["notes"]}")
          
        {:error, reason} ->
          IO.puts("Result: ERROR - #{reason}")
      end
    end)
    
    # Test the agent with test mode as well
    IO.puts("\n=== Testing Agent compare_providers handler ===")
    
    # Start the agent
    agent_opts = [name: "test-bottle-scanner"]
    {:ok, agent_pid} = Chorus.Runtime.start_agent(PersonalBartender.BottleScannerAgent, agent_opts)
    
    # Test the compare_providers message
    message = %{type: "compare_providers", image_path: "image_2_single_bottle.png"}
    case Chorus.Agent.Server.perform(agent_pid, message) do
      {:ok, response} ->
        IO.puts("Agent comparison succeeded!")
        IO.inspect(response, limit: :infinity, pretty: true)
        
      {:error, reason} ->
        IO.puts("Agent comparison failed: #{reason}")
    end
    
    # Clean up
    GenServer.stop(agent_pid)
    
  {:error, reason} ->
    IO.puts("Provider comparison failed: #{reason}")
end

IO.puts("\nTest completed!")