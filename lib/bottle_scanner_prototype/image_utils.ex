defmodule BottleScannerPrototype.ImageUtils do
  @moduledoc """
  Utilities for image processing and optimization for vision API calls.
  
  This module provides functions to resize and optimize images to reduce
  API call costs and improve response times.
  """
  
  require Logger
  
  @doc """
  Resize an image to fit within specified dimensions while maintaining aspect ratio.
  
  ## Options
  
  - `:max_width` - Maximum width in pixels (default: 1024)
  - `:max_height` - Maximum height in pixels (default: 1024)
  - `:quality` - JPEG quality 1-100 (default: 85)
  - `:format` - Output format (default: :jpeg)
  
  ## Examples
  
      iex> PersonalBartender.ImageUtils.resize_image("path/to/large.png")
      {:ok, resized_data_url}
      
      iex> PersonalBartender.ImageUtils.resize_image("path/to/image.jpg", max_width: 512)
      {:ok, resized_data_url}
  """
  def resize_image(image_path, opts \\ []) do
    max_width = Keyword.get(opts, :max_width, 1024)
    max_height = Keyword.get(opts, :max_height, 1024)
    quality = Keyword.get(opts, :quality, 85)
    format = Keyword.get(opts, :format, :jpeg)
    
    try do
      # First try with the Image library
      case Image.open(image_path) do
        {:ok, image} ->
          # Get image dimensions - handle both tuple and struct formats
          {original_width, original_height} = case Image.shape(image) do
            {w, h} -> {w, h}
            {w, h, _channels} -> {w, h}
            %{width: w, height: h} -> {w, h}
            other -> 
              Logger.warning("Unexpected shape format: #{inspect(other)}")
              {1024, 1024}  # fallback
          end
          
          {new_width, new_height} = calculate_new_dimensions(original_width, original_height, max_width, max_height)
          
          # Resize the image
          case Image.resize(image, new_width, new_height) do
            {:ok, resized_image} ->
              # Convert to desired format and get binary data
              case Image.write(resized_image, format: format, quality: quality) do
                {:ok, image_binary} ->
                  mime_type = get_mime_type(format)
                  base64_data = Base.encode64(image_binary)
                  data_url = "data:#{mime_type};base64,#{base64_data}"
                  
                  original_size = File.stat!(image_path).size
                  new_size = byte_size(image_binary)
                  compression_ratio = Float.round((1 - new_size / original_size) * 100, 1)
                  
                  Logger.info("Image resized: #{original_width}x#{original_height} (#{format_bytes(original_size)}) -> #{new_width}x#{new_height} (#{format_bytes(new_size)}) - #{compression_ratio}% reduction")
                  
                  {:ok, data_url}
                  
                {:error, reason} ->
                  Logger.error("Failed to write resized image: #{inspect(reason)}")
                  {:error, "Image write failed: #{inspect(reason)}"}
              end
              
            {:error, reason} ->
              Logger.error("Failed to resize image: #{inspect(reason)}")
              {:error, "Image resize failed: #{inspect(reason)}"}
          end
          
        {:error, reason} ->
          Logger.error("Failed to open image #{image_path}: #{inspect(reason)}")
          # Fallback: try simple base64 encoding without processing for very large files
          fallback_encode_image(image_path, max_width, max_height)
      end
    rescue
      error ->
        Logger.error("Exception while processing image #{image_path}: #{inspect(error)}")
        # Fallback: try simple base64 encoding without processing
        fallback_encode_image(image_path, max_width, max_height)
    end
  end
  
  # Fallback function that tries sips for large images, then simple encoding
  defp fallback_encode_image(image_path, max_width, max_height) do
    case File.read(image_path) do
      {:ok, binary_data} ->
        # Check if file is reasonable size (under 5MB for base64 encoding)
        if byte_size(binary_data) < 5_000_000 do
          # Small enough - encode directly
          encode_image_data(binary_data, image_path)
        else
          # Too large - try to resize with sips (macOS built-in tool)
          Logger.info("Image too large (#{format_bytes(byte_size(binary_data))}), attempting resize with sips...")
          case resize_with_sips(image_path, max_width, max_height) do
            {:ok, resized_path} ->
              # Read the resized image and encode it
              case File.read(resized_path) do
                {:ok, resized_data} ->
                  # Clean up temporary file
                  File.rm(resized_path)
                  
                  original_size = byte_size(binary_data)
                  new_size = byte_size(resized_data)
                  compression_ratio = Float.round((1 - new_size / original_size) * 100, 1)
                  
                  Logger.info("Image resized with sips: #{format_bytes(original_size)} -> #{format_bytes(new_size)} (#{compression_ratio}% reduction)")
                  encode_image_data(resized_data, resized_path)
                  
                {:error, reason} ->
                  File.rm(resized_path)  # Clean up
                  {:error, "Failed to read resized image: #{inspect(reason)}"}
              end
              
            {:error, reason} ->
              Logger.error("sips resize failed: #{reason}")
              {:error, "Image too large and cannot be processed (#{format_bytes(byte_size(binary_data))})"}
          end
        end
        
      {:error, reason} ->
        {:error, "Failed to read image file: #{inspect(reason)}"}
    end
  end
  
  # Helper function to encode image binary data as data URL
  defp encode_image_data(binary_data, image_path) do
    mime_type = case Path.extname(image_path) |> String.downcase() do
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      _ -> "image/jpeg"
    end
    
    base64_data = Base.encode64(binary_data)
    data_url = "data:#{mime_type};base64,#{base64_data}"
    
    Logger.info("Encoded image: #{image_path} (#{format_bytes(byte_size(binary_data))})")
    {:ok, data_url}
  end
  
  # Use macOS sips command to resize large images
  defp resize_with_sips(image_path, max_width, max_height) do
    # Create temporary output path
    temp_dir = System.tmp_dir!()
    temp_filename = "resized_#{System.unique_integer()}.jpg"
    temp_path = Path.join(temp_dir, temp_filename)
    
    # Use sips to resize the image, maintaining aspect ratio
    max_dimension = max(max_width, max_height)
    
    case System.cmd("sips", [
      "-Z", "#{max_dimension}",           # Resize maintaining aspect ratio
      "-s", "format", "jpeg",             # Convert to JPEG
      "-s", "formatOptions", "85",        # Set JPEG quality to 85%
      image_path,
      "--out", temp_path
    ], stderr_to_stdout: true) do
      {_output, 0} ->
        # Success
        {:ok, temp_path}
        
      {output, exit_code} ->
        # Failed
        Logger.error("sips command failed (exit code #{exit_code}): #{output}")
        {:error, "sips resize failed: #{output}"}
    end
  rescue
    error ->
      Logger.error("Exception running sips: #{inspect(error)}")
      {:error, "sips command error: #{inspect(error)}"}
  end
  
  @doc """
  Get optimal dimensions for an image based on file size and API requirements.
  
  Larger files get more aggressive compression to stay within API limits.
  """
  def get_optimal_dimensions(image_path) do
    case File.stat(image_path) do
      {:ok, %{size: size}} when size > 20_000_000 ->
        # Very large files (>20MB) - aggressive compression
        {512, 512}
        
      {:ok, %{size: size}} when size > 10_000_000 ->
        # Large files (>10MB) - moderate compression
        {768, 768}
        
      {:ok, %{size: size}} when size > 5_000_000 ->
        # Medium files (>5MB) - light compression
        {1024, 1024}
        
      {:ok, _} ->
        # Small files - minimal compression
        {1280, 1280}
        
      {:error, _} ->
        # Default fallback
        {1024, 1024}
    end
  end
  
  @doc """
  Create a resized data URL from a local image file, optimized for vision APIs.
  """
  def create_optimized_data_url(image_path) do
    {max_width, max_height} = get_optimal_dimensions(image_path)
    
    resize_image(image_path, 
      max_width: max_width, 
      max_height: max_height,
      quality: 85,
      format: :jpeg
    )
  end
  
  # Private helper functions
  
  defp calculate_new_dimensions(width, height, max_width, max_height) do
    # Calculate scaling factor to fit within bounds while maintaining aspect ratio
    width_scale = max_width / width
    height_scale = max_height / height
    scale = min(width_scale, height_scale)
    
    # Only scale down, never scale up
    scale = min(scale, 1.0)
    
    new_width = round(width * scale)
    new_height = round(height * scale)
    
    {new_width, new_height}
  end
  
  defp get_mime_type(:jpeg), do: "image/jpeg"
  defp get_mime_type(:jpg), do: "image/jpeg"
  defp get_mime_type(:png), do: "image/png"
  defp get_mime_type(:webp), do: "image/webp"
  defp get_mime_type(_), do: "image/jpeg"
  
  defp format_bytes(bytes) when bytes >= 1_048_576 do
    "#{Float.round(bytes / 1_048_576, 1)}MB"
  end
  
  defp format_bytes(bytes) when bytes >= 1024 do
    "#{Float.round(bytes / 1024, 1)}KB"
  end
  
  defp format_bytes(bytes) do
    "#{bytes}B"
  end
end