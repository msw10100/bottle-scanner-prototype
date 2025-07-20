# Test script to verify bottle scanner agent handlers and API configuration
#
# Run this in iex with:
# iex> c("test_agent_handlers.exs")

defmodule HandlerTest do
  def run_tests do
    IO.puts("🧪 Testing Bottle Scanner Agent Handlers")
    IO.puts("=" |> String.duplicate(50))
    
    # Test 1: Basic handler routing with get_stats
    IO.puts("\n📊 Test 1: Testing get_stats handler...")
    case PersonalBartender.get_agent_stats() do
      {:ok, stats} ->
        IO.puts("   ✅ get_stats handler working: #{inspect(stats)}")
      {:error, reason} ->
        IO.puts("   ❌ get_stats failed: #{reason}")
    end
    
    # Test 2: Check API key availability
    IO.puts("\n🔑 Test 2: Checking API key configuration...")
    api_keys = %{
      openai: System.get_env("OPENAI_API_KEY"),
      anthropic: System.get_env("ANTHROPIC_API_KEY"),
      google: System.get_env("GOOGLE_API_KEY") || System.get_env("GEMINI_API_KEY")
    }
    
    Enum.each(api_keys, fn {provider, key} ->
      status = if key && String.length(key) > 10, do: "✅ Configured", else: "❌ Missing"
      IO.puts("   #{provider}: #{status}")
    end)
    
    # Test 3: Test with test mode (no API calls)
    IO.puts("\n🧪 Test 3: Testing with test mode...")
    old_provider = System.get_env("VISION_PROVIDER")
    System.put_env("VISION_PROVIDER", "test")
    
    case PersonalBartender.scan_with_agent("image_1_multi_bottle.png") do
      {:ok, result} ->
        IO.puts("   ✅ Test mode scan working: #{inspect(result)}")
      {:error, reason} ->
        IO.puts("   ❌ Test mode scan failed: #{reason}")
    end
    
    # Restore original provider
    if old_provider, do: System.put_env("VISION_PROVIDER", old_provider), else: System.delete_env("VISION_PROVIDER")
    
    # Test 4: List available images
    IO.puts("\n📁 Test 4: Available images...")
    case PersonalBartender.list_available_images() do
      {:ok, images} ->
        IO.puts("   ✅ Found #{length(images)} images:")
        Enum.each(images, fn image -> IO.puts("      • #{image}") end)
      {:error, reason} ->
        IO.puts("   ❌ Failed to list images: #{reason}")
    end
    
    IO.puts("\n🏁 Test completed!")
  end
end

# Run the tests
HandlerTest.run_tests()