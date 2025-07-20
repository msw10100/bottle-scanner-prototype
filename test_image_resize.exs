#!/usr/bin/env elixir

# Test script for image resizing functionality
IO.puts("Testing image resizing functionality...")

# Get the full path to the test image
full_path = Path.join([Application.app_dir(:personal_bartender), "priv", "data", "images", "image_1_multi_bottle.png"])

IO.puts("Full image path: #{full_path}")
IO.puts("Image exists: #{File.exists?(full_path)}")

# Check file size
case File.stat(full_path) do
  {:ok, %{size: size}} ->
    size_mb = Float.round(size / 1_048_576, 1)
    IO.puts("Original file size: #{size_mb}MB")
    
  {:error, reason} ->
    IO.puts("Error getting file stats: #{inspect(reason)}")
end

# Test image resizing with ImageUtils
IO.puts("\n=== Testing ImageUtils.create_optimized_data_url ===")
case PersonalBartender.ImageUtils.create_optimized_data_url(full_path) do
  {:ok, data_url} ->
    # Get just the base64 part to check size
    case String.split(data_url, ",", parts: 2) do
      [header, base64_data] ->
        original_size = byte_size(base64_data)
        decoded_size = byte_size(Base.decode64!(base64_data))
        IO.puts("Success! Data URL created")
        IO.puts("Header: #{String.slice(header, 0..40)}...")
        IO.puts("Base64 data length: #{byte_size(base64_data)} characters")
        decoded_mb = Float.round(decoded_size / 1_048_576, 1)
        IO.puts("Decoded image size: #{decoded_mb}MB")
        
        # Test with VisionAPI compare_providers using this data URL
        IO.puts("\n=== Testing VisionAPI.compare_providers with resized image ===")
        case PersonalBartender.VisionAPI.compare_providers(data_url) do
          {:ok, results} ->
            IO.puts("Provider comparison succeeded!")
            Enum.each(results, fn {provider, data} ->
              IO.puts("#{provider}: #{inspect(data.result)} (#{data.duration_ms}ms)")
            end)
            
          {:error, reason} ->
            IO.puts("Provider comparison failed: #{reason}")
        end
        
      _ ->
        IO.puts("Failed to parse data URL")
    end
    
  {:error, reason} ->
    IO.puts("Image resize failed: #{reason}")
end

IO.puts("\nTest completed!")