defmodule BottleScannerPrototypeWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  import Phoenix.HTML

  @doc """
  Renders flash notices.
  """
  attr :flash, :map, default: %{}, doc: "the map of flash messages"
  attr :id, :string, default: "flash", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash :for={{kind, message} <- @flash} kind={kind} phx-mounted={show("##{@id}-#{kind}")}>
        <%= message %>
      </.flash>
    </div>
    """
  end

  @doc """
  Renders a flash notice.
  """
  attr :id, :string, default: nil, doc: "the optional id of flash container"
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      style="position: fixed; top: 1rem; right: 1rem; z-index: 50; max-width: 24rem; padding: 1rem; border-radius: 0.5rem; border: 1px solid; background: white;"
      {@rest}
    >
      <p style="margin: 0; font-weight: 600;">
        <%= msg || render_slot(@inner_block) %>
      </p>
      <button type="button" style="position: absolute; top: 0.25rem; right: 0.5rem; background: none; border: none; cursor: pointer;" aria-label="close">
        ✕
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with JS commands.
  """
  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition: {"transition-all transform ease-out duration-300", "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95", "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  @doc """
  Hides the flash group with JS commands.
  """
  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition: {"transition-all transform ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100", "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Renders a simple form.
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div>
        <%= render_slot(@inner_block, f) %>
        <div :for={action <- @actions}>
          <%= render_slot(action, f) %>
        </div>
      </div>
    </.form>
    """
  end
end