defmodule PersonalBartender.TidewaveServer do
  @moduledoc """
  Tidewave MCP Server for Personal Bartender debugging and introspection.
  
  This module provides MCP (Model Context Protocol) endpoints for debugging
  and interacting with the Chorus system via the tidewave protocol.
  """
  
  use Plug.Router
  
  plug Plug.Logger
  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch
  
  # MCP endpoint for tidewave
  post "/tidewave/mcp" do
    handle_mcp_request(conn)
  end
  
  # SSE endpoint for real-time updates
  get "/tidewave/mcp" do
    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("access-control-allow-origin", "*")
    |> send_chunked(200)
    |> handle_sse_connection()
  end
  
  # Health check endpoint
  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "ok", service: "tidewave-mcp"}))
  end
  
  # Catch-all
  match _ do
    send_resp(conn, 404, "Not found")
  end
  
  defp handle_mcp_request(conn) do
    case conn.body_params do
      %{"method" => method} = request ->
        response = process_mcp_method(method, request)
        send_resp(conn, 200, Jason.encode!(response))
      
      _ ->
        error_response = %{
          error: %{
            code: -32600,
            message: "Invalid Request"
          }
        }
        send_resp(conn, 400, Jason.encode!(error_response))
    end
  end
  
  defp handle_sse_connection(conn) do
    # Send initial connection event
    {:ok, conn} = chunk(conn, "event: connected\ndata: {\"status\": \"connected\"}\n\n")
    
    # Keep connection alive and send periodic updates
    send_periodic_updates(conn)
  end
  
  defp send_periodic_updates(conn) do
    # Send system status every 5 seconds
    :timer.sleep(5000)
    
    system_info = get_system_info()
    event_data = Jason.encode!(system_info)
    
    case chunk(conn, "event: system_status\ndata: #{event_data}\n\n") do
      {:ok, conn} -> send_periodic_updates(conn)
      {:error, _} -> conn  # Connection closed
    end
  end
  
  defp process_mcp_method("initialize", request) do
    %{
      result: %{
        protocolVersion: "2024-11-05",
        capabilities: %{
          tools: %{},
          resources: %{
            subscribe: true,
            listChanged: true
          },
          prompts: %{},
          logging: %{}
        },
        serverInfo: %{
          name: "tidewave-chorus-interactive",
          version: "0.1.0"
        }
      },
      id: Map.get(request, "id")
    }
  end
  
  defp process_mcp_method("resources/list", request) do
    resources = [
      %{
        uri: "chorus://system/status",
        name: "System Status",
        description: "Current system status and metrics",
        mimeType: "application/json"
      },
      %{
        uri: "chorus://agents/list", 
        name: "Agent List",
        description: "List of all registered agents",
        mimeType: "application/json"
      },
      %{
        uri: "chorus://runtime/info",
        name: "Runtime Information", 
        description: "Chorus runtime configuration and state",
        mimeType: "application/json"
      }
    ]
    
    %{
      result: %{
        resources: resources
      },
      id: Map.get(request, "id")
    }
  end
  
  defp process_mcp_method("resources/read", request) do
    case get_in(request, ["params", "uri"]) do
      "chorus://system/status" ->
        %{
          result: %{
            contents: [%{
              uri: "chorus://system/status",
              mimeType: "application/json",
              text: Jason.encode!(get_system_info(), pretty: true)
            }]
          },
          id: Map.get(request, "id")
        }
        
      "chorus://agents/list" ->
        %{
          result: %{
            contents: [%{
              uri: "chorus://agents/list", 
              mimeType: "application/json",
              text: Jason.encode!(get_agents_info(), pretty: true)
            }]
          },
          id: Map.get(request, "id")
        }
        
      "chorus://runtime/info" ->
        %{
          result: %{
            contents: [%{
              uri: "chorus://runtime/info",
              mimeType: "application/json", 
              text: Jason.encode!(get_runtime_info(), pretty: true)
            }]
          },
          id: Map.get(request, "id")
        }
        
      uri ->
        %{
          error: %{
            code: -32602,
            message: "Resource not found: #{uri}"
          },
          id: Map.get(request, "id")
        }
    end
  end
  
  defp process_mcp_method(method, request) do
    %{
      error: %{
        code: -32601,
        message: "Method not found: #{method}"
      },
      id: Map.get(request, "id")
    }
  end
  
  defp get_system_info do
    %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      node: Node.self(),
      system_info: %{
        elixir_version: System.version(),
        otp_version: System.otp_release(),
        memory_usage: :erlang.memory(),
        process_count: :erlang.system_info(:process_count)
      },
      chorus_status: get_chorus_status()
    }
  end
  
  defp get_agents_info do
    # Try to get registered agents from Chorus runtime
    case Process.whereis(Chorus.Runtime.Registry) do
      nil -> 
        %{
          agents: [],
          registry_status: "not_running",
          message: "Chorus Runtime Registry not found"
        }
      
      _pid ->
        %{
          agents: [],
          registry_status: "running", 
          message: "Registry found but agent enumeration not implemented yet"
        }
    end
  end
  
  defp get_runtime_info do
    %{
      chorus_application_status: get_application_status(:chorus),
      chorus_llm_status: get_application_status(:chorus_llm),
      chorus_storage_status: get_application_status(:chorus_storage),
      config: %{
        observability: Application.get_env(:chorus, :observability, :not_set),
        telemetry: Application.get_env(:chorus, :telemetry, :not_set),
        runtime: Application.get_env(:chorus, :runtime, :not_set)
      }
    }
  end
  
  defp get_chorus_status do
    case Application.started_applications() do
      apps when is_list(apps) ->
        chorus_apps = Enum.filter(apps, fn {app, _, _} -> 
          app_name = to_string(app)
          String.starts_with?(app_name, "chorus")
        end)
        
        %{
          running_applications: Enum.map(chorus_apps, fn {app, _desc, version} -> 
            %{name: app, version: version}
          end),
          total_chorus_apps: length(chorus_apps)
        }
        
      _ ->
        %{
          running_applications: [],
          total_chorus_apps: 0,
          error: "Could not enumerate applications"
        }
    end
  end
  
  defp get_application_status(app_name) do
    case Application.started_applications() do
      apps when is_list(apps) ->
        case Enum.find(apps, fn {app, _, _} -> app == app_name end) do
          {^app_name, _desc, version} -> %{status: "running", version: version}
          nil -> %{status: "not_running"}
        end
        
      _ ->
        %{status: "unknown", error: "Could not check application status"}
    end
  end
end