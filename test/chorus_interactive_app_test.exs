defmodule ChorusInteractiveAppTest do
  use ExUnit.Case
  doctest ChorusInteractiveApp

  test "greets the world" do
    assert ChorusInteractiveApp.hello() == :world
  end
end