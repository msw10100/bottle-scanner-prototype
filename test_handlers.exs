#!/usr/bin/env elixir

# Simple test script to verify Chorus Agent handler pattern matching
# This script tests our bottle scanner agent handlers without starting the full application

Mix.install([
  {:chorus, path: "../../apps/chorus"},
  {:jason, "~> 1.4"}
])

defmodule TestBottleScannerAgent do
  @moduledoc """
  Minimal test agent to verify handler pattern matching
  """
  
  use Chorus.Agent
  
  agent do
    name "test-bottle-scanner"
    role "Test bottle recognition agent"
    
    init_agent_state(%{
      test_count: 0
    })
  end
  
  # Test the exact same pattern our bottle scanner uses
  handle %{type: "get_stats"} do
    IO.puts("✅ get_stats handler matched successfully!")
    stats = %{
      test_count: agent_state.test_count,
      message: "Handler is working correctly"
    }
    {:ok, stats, agent_state}
  end
  
  handle %{type: "scan_bottle", image_path: image_path} do
    IO.puts("✅ scan_bottle handler matched successfully for: #{image_path}")
    new_state = %{agent_state | test_count: agent_state.test_count + 1}
    {:ok, %{image_path: image_path, result: "test success"}, new_state}
  end
  
  handle %{type: "compare_providers", image_path: image_path} do
    IO.puts("✅ compare_providers handler matched successfully for: #{image_path}")
    {:ok, %{image_path: image_path, providers: ["test"]}, agent_state}
  end
  
  handle msg do
    IO.puts("❌ Fell through to catch-all handler with: #{inspect(msg)}")
    {:ok, "Test catch-all: #{inspect(msg)}", agent_state}
  end
end

# Test the agent
IO.puts("🧪 Testing Chorus Agent Handler Pattern Matching")
IO.puts("=" |> String.duplicate(50))

# Start the agent
{:ok, agent_pid} = Chorus.Runtime.summon(TestBottleScannerAgent, name: "test-agent")
IO.puts("✅ Agent started successfully: #{inspect(agent_pid)}")

# Test each handler
IO.puts("\n📋 Testing get_stats handler:")
{:ok, result1} = Chorus.Runtime.perform(agent_pid, %{type: "get_stats"})
IO.puts("Result: #{inspect(result1)}")

IO.puts("\n📷 Testing scan_bottle handler:")
{:ok, result2} = Chorus.Runtime.perform(agent_pid, %{type: "scan_bottle", image_path: "test.jpg"})
IO.puts("Result: #{inspect(result2)}")

IO.puts("\n🔍 Testing compare_providers handler:")
{:ok, result3} = Chorus.Runtime.perform(agent_pid, %{type: "compare_providers", image_path: "test.jpg"})
IO.puts("Result: #{inspect(result3)}")

IO.puts("\n❓ Testing unknown message (should hit catch-all):")
{:ok, result4} = Chorus.Runtime.perform(agent_pid, %{type: "unknown_action"})
IO.puts("Result: #{inspect(result4)}")

IO.puts("\n🏁 Test completed!")