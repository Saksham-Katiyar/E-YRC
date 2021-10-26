defmodule ToyTest do
  use ExUnit.Case
  doctest Toy

  test "greets the world" do
    assert Toy.hello() == :world
  end
end
