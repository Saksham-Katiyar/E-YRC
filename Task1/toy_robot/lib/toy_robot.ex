defmodule ToyRobot do

  @table_top_x 4
  @table_top_y 4

  @moduledoc """
  Documentation for `ToyRobot`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> ToyRobot.hello()
      :world

  """
  def hello do
    :world
  end

  def place do
    {:ok, %ToyRobot.Position{}}
  end

  def place(x, y, _facing) when x<0 or y<0 or x>@table_top_x or y>@table_top_y do
    {:failure, "Invalid position"}
  end

  def place(_x, _y, facing) when facing not in [:north, :south, :east, :west] do
    {:failure, "Invalid facing direction"}
  end

  def place(x, y, facing) do
    robot = %ToyRobot.Position{x: x, y: y, facing: facing}
    {:ok, robot}
  end

  def report(robot) do
    %ToyRobot.Position{x: x, y: y, facing: facing} = robot
    {x, y, facing}
  end

  @direction_to_the_right %{north: :east, east: :south, south: :west, west: :north}
  def right(robot) do
    %ToyRobot.Position{facing: facing} = robot
    %ToyRobot.Position{robot | facing: @direction_to_the_right[facing]}
  end

  @direction_to_the_left Enum.map(@direction_to_the_right, fn {from, to} -> {to, from} end)
  def left(%ToyRobot.Position{facing: facing} = robot) do
    #directions_to_the_left = %{north: :west, west: :south, south: :east, east: :north}
    %ToyRobot.Position{robot | facing: @direction_to_the_left[facing]}
  end

  def move(%ToyRobot.Position{x: _, y: y, facing: :north} = robot) when y < @table_top_y do
    %ToyRobot.Position{robot | y: y+1}
  end

  def move(%ToyRobot.Position{x: _, y: y, facing: :south} = robot) when y > 0 do
    %ToyRobot.Position{robot | y: y-1}
  end

  def move(%ToyRobot.Position{x: x, y: _, facing: :west} = robot) when x > 0 do
    %ToyRobot.Position{robot | x: x-1}
  end

  def move(%ToyRobot.Position{x: x, y: _, facing: :east} = robot) when x < @table_top_x do
    %ToyRobot.Position{robot | x: x+1}
  end

  def move(robot), do: robot
end
