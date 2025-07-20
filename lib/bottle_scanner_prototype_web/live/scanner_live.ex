defmodule BottleScannerPrototypeWeb.ScannerLive do
  use BottleScannerPrototypeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket = 
      socket
      |> allow_upload(:photo, 
          accept: ~w(.jpg .jpeg .png .webp),
          max_entries: 1,
          max_file_size: 50_000_000, # 50MB
          progress: &handle_progress/3,
          auto_upload: true
        )
      |> assign(:scanning, false)
      |> assign(:results, nil)
      |> assign(:error, nil)
      |> assign(:upload_progress, 0)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("scan-bottle", _params, socket) do
    # This will be triggered by auto_upload when file is selected
    {:noreply, socket}
  end

  @impl true
  def handle_event("retry", _params, socket) do
    socket = 
      socket
      |> assign(:error, nil)
      |> assign(:results, nil)
      |> assign(:scanning, false)
      |> assign(:upload_progress, 0)
    
    {:noreply, socket}
  end

  # Handle upload progress
  defp handle_progress(:photo, entry, socket) do
    if entry.done? do
      # Process the uploaded image
      socket
      |> assign(:scanning, true)
      |> assign(:upload_progress, 100)
      |> process_uploaded_image()
    else
      # Update progress bar
      socket
      |> assign(:upload_progress, entry.progress)
    end
  end

  # Process the uploaded image
  defp process_uploaded_image(socket) do
    uploaded_files = consume_uploaded_entries(socket, :photo, fn %{path: path}, _entry ->
      case scan_bottle_image(path) do
        {:ok, results} -> {:ok, results}
        {:error, reason} -> 
          # Log error and return it
          require Logger
          Logger.error("Image processing failed: #{inspect(reason)}")
          {:postpone, reason}
      end
    end)

    case uploaded_files do
      [results] -> 
        socket
        |> assign(:scanning, false)
        |> assign(:results, results)
        |> assign(:error, nil)
        |> assign(:upload_progress, 0)
      [] -> 
        socket
        |> assign(:scanning, false)
        |> assign(:error, "Failed to process image")
        |> assign(:upload_progress, 0)
    end
  end

  # Integration with existing VisionAPI
  defp scan_bottle_image(image_path) do
    with {:ok, data_url} <- BottleScannerPrototype.ImageUtils.create_optimized_data_url(image_path),
         {:ok, results} <- BottleScannerPrototype.VisionAPI.compare_providers(data_url) do
      {:ok, results}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Helper function for error messages
  defp error_to_string(:too_large), do: "File too large (max 50MB)"
  defp error_to_string(:too_many_files), do: "Only one file at a time"
  defp error_to_string(:not_accepted), do: "Invalid file type (use JPG, PNG, or WebP)"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="scanner-app">
      <div class="header">
        <h1>🍺 AI Bottle Scanner</h1>
        <p>Compare 4 AI providers instantly</p>
      </div>
      
      <div class="upload-section">
        <form phx-change="validate" phx-submit="scan-bottle" phx-drop-target={@uploads.photo.ref}>
          
          <!-- Camera/Gallery Upload Buttons -->
          <div class="upload-container">
            <label for={@uploads.photo.ref} class="upload-button camera-button">
              <div class="button-content">
                <div class="icon">📷</div>
                <span>Take Photo</span>
              </div>
              <input 
                type="file" 
                accept="image/*" 
                capture="camera"
                style="display: none;"
              />
            </label>

            <label for={@uploads.photo.ref <> "-gallery"} class="upload-button gallery-button">
              <div class="button-content">
                <div class="icon">🖼️</div>
                <span>Choose from Gallery</span>
              </div>
              <input 
                type="file" 
                accept="image/*"
                style="display: none;"
              />
            </label>
          </div>

          <!-- Upload Progress -->
          <%= if @upload_progress > 0 and @upload_progress < 100 do %>
            <div class="progress-container">
              <div class="progress-bar">
                <div class="progress-fill" style={"width: #{@upload_progress}%"}></div>
              </div>
              <span class="progress-text"><%= @upload_progress %>%</span>
            </div>
          <% end %>

          <!-- Upload Errors -->
          <%= for err <- upload_errors(@uploads.photo) do %>
            <div class="error-message">
              <%= error_to_string(err) %>
            </div>
          <% end %>

          <!-- File Validation Errors -->
          <%= for entry <- @uploads.photo.entries do %>
            <%= for err <- upload_errors(@uploads.photo, entry) do %>
              <div class="error-message">
                <%= error_to_string(err) %>
              </div>
            <% end %>
          <% end %>
        </form>
      </div>

      <!-- Scanning Status -->
      <%= if @scanning do %>
        <div class="scanning-status">
          <div class="spinner"></div>
          <h3>Analyzing your bottle...</h3>
          <p>Comparing results from 4 AI providers</p>
          <div class="provider-list">
            <span class="provider">OpenAI GPT-4V</span>
            <span class="provider">Claude 3.5 Sonnet</span>
            <span class="provider">Gemini Pro Vision</span>
            <span class="provider">OpenRouter</span>
          </div>
        </div>
      <% end %>

      <!-- Results Display -->
      <%= if @results do %>
        <div class="results-section">
          <h2>🔍 Analysis Results</h2>
          <div class="results-grid">
            <%= for {provider, data} <- @results do %>
              <div class="provider-card">
                <div class="provider-header">
                  <h3><%= format_provider_name(provider) %></h3>
                  <span class="response-time"><%= data.duration_ms %>ms</span>
                </div>
                
                <%= case data.result do %>
                  <% {:ok, result} -> %>
                    <div class="result-content success">
                      <div class="bottle-info">
                        <strong class="bottle-name"><%= result["brand"] %> <%= result["type"] %></strong>
                        <%= if result["details"] do %>
                          <p class="bottle-details"><%= result["details"] %></p>
                        <% end %>
                      </div>
                    </div>
                  <% {:error, reason} -> %>
                    <div class="result-content error">
                      <span class="error-icon">❌</span>
                      <span class="error-text"><%= reason %></span>
                    </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="action-buttons">
            <button phx-click="retry" class="retry-button">
              📷 Scan Another Bottle
            </button>
          </div>
        </div>
      <% end %>

      <!-- Error Display -->
      <%= if @error do %>
        <div class="error-section">
          <div class="error-content">
            <span class="error-icon">❌</span>
            <p class="error-message"><%= @error %></p>
            <button phx-click="retry" class="retry-button">Try Again</button>
          </div>
        </div>
      <% end %>
    </div>

    <style>
      * { box-sizing: border-box; }
      
      body { 
        margin: 0; 
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        min-height: 100vh;
      }
      
      .scanner-app { 
        max-width: 400px; 
        margin: 0 auto; 
        padding: 20px;
        min-height: 100vh;
      }
      
      .header {
        text-align: center;
        color: white;
        margin-bottom: 30px;
      }
      
      .header h1 {
        font-size: 2rem;
        margin: 0 0 10px 0;
        text-shadow: 0 2px 4px rgba(0,0,0,0.3);
      }
      
      .header p {
        margin: 0;
        opacity: 0.9;
        font-size: 1.1rem;
      }
      
      .upload-container {
        display: flex;
        flex-direction: column;
        gap: 15px;
        margin-bottom: 20px;
      }
      
      .upload-button {
        display: flex;
        justify-content: center;
        align-items: center;
        padding: 20px;
        border: 2px dashed rgba(255,255,255,0.3);
        border-radius: 12px;
        cursor: pointer;
        transition: all 0.3s ease;
        background: rgba(255,255,255,0.1);
        backdrop-filter: blur(10px);
        color: white;
        text-decoration: none;
      }
      
      .upload-button:hover {
        border-color: rgba(255,255,255,0.6);
        background: rgba(255,255,255,0.2);
        transform: translateY(-2px);
      }
      
      .button-content {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 8px;
      }
      
      .icon {
        font-size: 2rem;
      }
      
      .progress-container {
        display: flex;
        align-items: center;
        gap: 10px;
        margin: 10px 0;
      }
      
      .progress-bar {
        flex: 1;
        height: 8px;
        background: rgba(255,255,255,0.2);
        border-radius: 4px;
        overflow: hidden;
      }
      
      .progress-fill {
        height: 100%;
        background: #4CAF50;
        transition: width 0.3s ease;
      }
      
      .progress-text {
        color: white;
        font-size: 0.9rem;
        min-width: 35px;
      }
      
      .scanning-status {
        text-align: center;
        padding: 30px 20px;
        background: rgba(255,255,255,0.1);
        backdrop-filter: blur(10px);
        border-radius: 12px;
        color: white;
        margin: 20px 0;
      }
      
      .spinner {
        border: 4px solid rgba(255,255,255,0.3);
        border-top: 4px solid white;
        border-radius: 50%;
        width: 40px;
        height: 40px;
        animation: spin 1s linear infinite;
        margin: 0 auto 20px;
      }
      
      @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
      }
      
      .provider-list {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        justify-content: center;
        margin-top: 15px;
      }
      
      .provider {
        background: rgba(255,255,255,0.2);
        padding: 4px 8px;
        border-radius: 6px;
        font-size: 0.8rem;
      }
      
      .results-section {
        background: rgba(255,255,255,0.95);
        border-radius: 12px;
        padding: 20px;
        margin: 20px 0;
      }
      
      .results-section h2 {
        margin: 0 0 20px 0;
        color: #333;
        text-align: center;
      }
      
      .results-grid {
        display: flex;
        flex-direction: column;
        gap: 15px;
      }
      
      .provider-card {
        border: 1px solid #e1e5e9;
        border-radius: 8px;
        padding: 15px;
        background: white;
      }
      
      .provider-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 10px;
      }
      
      .provider-header h3 {
        margin: 0;
        color: #007bff;
        font-size: 1rem;
      }
      
      .response-time {
        color: #666;
        font-size: 0.9rem;
        background: #f8f9fa;
        padding: 2px 6px;
        border-radius: 4px;
      }
      
      .result-content.success {
        color: #28a745;
      }
      
      .result-content.error {
        color: #dc3545;
        display: flex;
        align-items: center;
        gap: 8px;
      }
      
      .bottle-name {
        font-size: 1.1rem;
        display: block;
        margin-bottom: 5px;
      }
      
      .bottle-details {
        margin: 0;
        color: #666;
        line-height: 1.4;
      }
      
      .action-buttons {
        text-align: center;
        margin-top: 20px;
      }
      
      .retry-button {
        background: #007bff;
        color: white;
        border: none;
        padding: 12px 24px;
        border-radius: 8px;
        cursor: pointer;
        font-size: 1rem;
        transition: background 0.3s ease;
      }
      
      .retry-button:hover {
        background: #0056b3;
      }
      
      .error-section {
        background: rgba(220, 53, 69, 0.1);
        border: 1px solid rgba(220, 53, 69, 0.3);
        border-radius: 12px;
        padding: 20px;
        margin: 20px 0;
        text-align: center;
      }
      
      .error-content {
        color: #721c24;
      }
      
      .error-icon {
        font-size: 2rem;
        display: block;
        margin-bottom: 10px;
      }
      
      .error-message {
        color: #dc3545;
        background: rgba(248, 215, 218, 0.8);
        padding: 10px;
        border-radius: 6px;
        margin: 10px 0;
      }
      
      @media (max-width: 480px) {
        .scanner-app {
          padding: 15px;
        }
        
        .header h1 {
          font-size: 1.7rem;
        }
        
        .upload-button {
          padding: 18px;
        }
      }
    </style>
    """
  end

  # Helper function to format provider names
  defp format_provider_name(:openai), do: "OpenAI GPT-4V"
  defp format_provider_name(:claude), do: "Claude 3.5 Sonnet"
  defp format_provider_name(:gemini), do: "Gemini Pro Vision"
  defp format_provider_name(:openrouter), do: "OpenRouter"
  defp format_provider_name(:test), do: "Test Mode"
  defp format_provider_name(provider), do: String.upcase(to_string(provider))
end