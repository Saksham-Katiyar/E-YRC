defmodule ToyRobotTest do
  use ExUnit.Case
  doctest ToyRobot

  test "greets the world" do
    assert ToyRobot.hello() == :world
  end

  test "places the Toy Robot on the table in the default position" do
    assert ToyRobot.place == %ToyRobot.Position{x: 0, y: 0, facing: :north}
  end

  test "places the Toy Robot on the table in the specified position" do
    assert ToyRobot.place(1,2,:south) == %ToyRobot.Position{x: 1,y: 2, facing: :south}
  end

  test "does not place the robot outside of the table" do
    assert ToyRobot.place(-1, -1, :north) == {:failure, "Invalid position"}
  end

  test "does not place the robot with invalid facing direction" do
    assert ToyRobot.place(0, 0, :north_east) == {:failure, "Invalid facing direction"}
  end

  test "provides the report of the robot's position" do
    robot = ToyRobot.place(2, 3, :west)
    assert ToyRobot.report(robot) == {2, 3, :west}
  end

  test "rotates the robot to the right" do
    position = ToyRobot.place(1, 3, :west)
    |>ToyRobot.right
    |>ToyRobot.report

    assert position == {1, 3, :north}

    position = ToyRobot.place(0, 0, :east)
    |>ToyRobot.right
    |>ToyRobot.right
    |>ToyRobot.report

    assert position == {0, 0, :west}
  end

  test "rotates the robot to the left" do
    position = ToyRobot.place(1, 3, :west)
    |>ToyRobot.left
    |>ToyRobot.report

    assert position == {1, 3, :south}

    position = ToyRobot.place(0, 0, :east)
    |>ToyRobot.left
    |>ToyRobot.left
    |>ToyRobot.report

    assert position == {0, 0, :west}
  end

  test "rotating the robot 3 times to the right is the same as rotating it to the left" do
    right_position = ToyRobot.place(0, 0, :north)
    |> ToyRobot.right
    |> ToyRobot.right
    |> ToyRobot.right
    |> ToyRobot.report

    left_position =  ToyRobot.place(0, 0, :north)
    |> ToyRobot.left
    |> ToyRobot.report

    assert right_position == left_position
  end

  test "moving robot up if it is facing to the north" do
    position = ToyRobot.place(0, 0, :north)
    |>ToyRobot.move
    |>ToyRobot.report

    assert position == {0, 1, :north}
  end

  test "moving robot up if it is facing to the south" do
    position = ToyRobot.place(0, 1, :south)
    |>ToyRobot.move
    |>ToyRobot.report

    assert position == {0, 0, :south}
  end

  test "moving robot up if it is facing to the east" do
    position = ToyRobot.place(0, 0, :east)
    |>ToyRobot.move
    |>ToyRobot.report

    assert position == {1, 0, :east}
  end

  test "moving robot up if it is facing to the west" do
    position = ToyRobot.place(1, 0, :west)
    |>ToyRobot.move
    |>ToyRobot.report

    assert position == {0, 0, :west}
  end

  test "prevent the robot to fall" do
    position = ToyRobot.place(2, 4, :north)
    |>ToyRobot.move
    |>ToyRobot.report

    assert position == {2, 4, :north}

    position = ToyRobot.place(4, 0, :south)
    |>ToyRobot.move
    |>ToyRobot.report

    assert position == {4, 0, :south}

    position = ToyRobot.place(4, 2, :east)
    |>ToyRobot.move
    |>ToyRobot.report

    assert position == {4, 2, :east}

    position = ToyRobot.place(0, 2, :west)
    |>ToyRobot.move
    |>ToyRobot.report

    assert position == {0, 2, :west}
  end
end
