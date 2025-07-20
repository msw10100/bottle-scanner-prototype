#!/usr/bin/env elixir

# Test script for multi-provider comparison functionality
IO.puts("Starting multi-provider comparison test...")

# Test the compare_providers functionality
result = PersonalBartender.scan_multiple_with_agent("image_1_multi_bottle.png")

IO.puts("\n=== MULTI-PROVIDER COMPARISON RESULTS ===")
IO.inspect(result, limit: :infinity, pretty: true)

IO.puts("\nTest completed!")