defmodule AdTest do
  use ExUnit.Case
  doctest Ad

  test "greets the world" do
    assert Ad.hello() == :world
  end
end
