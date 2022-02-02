defmodule FW_DEMOTest do
  use ExUnit.Case
  doctest FW_DEMO

  test "greets the world" do
    assert FW_DEMO.hello() == :world
  end
end
