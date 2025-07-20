defmodule BottleScannerPrototypeWeb.Router do
  use BottleScannerPrototypeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BottleScannerPrototypeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BottleScannerPrototypeWeb do
    pipe_through :browser

    live "/", ScannerLive, :index
  end
end