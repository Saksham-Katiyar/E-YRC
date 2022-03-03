defmodule Task4CClientRobotB do
  # max x-coordinate of table top
  @table_top_x 6
  # max y-coordinate of table top
  @table_top_y :f
  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5, :f => 6}

  @doc """
  Places the robot to the default position of (1, A, North)

  Examples:

      iex> Task4CClientRobotB.place
      {:ok, %Task4CClientRobotB.Position{facing: :north, x: 1, y: :a}}
  """
  def place do
    {:ok, %Task4CClientRobotB.Position{}}
  end

  def place(x, y, _facing) when x < 1 or y < :a or x > @table_top_x or y > @table_top_y do
    {:failure, "Invalid position"}
  end

  def place(_x, _y, facing) when facing not in [:north, :east, :south, :west] do
    {:failure, "Invalid facing direction"}
  end

  @doc """
  Places the robot to the provided position of (x, y, facing),
  but prevents it to be placed outside of the table and facing invalid direction.

  Examples:

      iex> Task4CClientRobotB.place(1, :b, :south)
      {:ok, %Task4CClientRobotB.Position{facing: :south, x: 1, y: :b}}

      iex> Task4CClientRobotB.place(-1, :f, :north)
      {:failure, "Invalid position"}

      iex> Task4CClientRobotB.place(3, :c, :north_east)
      {:failure, "Invalid facing direction"}
  """
  def place(x, y, facing) do
    {:ok, %Task4CClientRobotB.Position{x: x, y: y, facing: facing}}
  end

  @doc """
  Provide START position to the robot as given location of (x, y, facing) and place it.
  """
  def start(x, y, facing) do
    place(x, y, facing)
  end

  @doc """
  Main function to initiate the sequence of tasks to achieve by the Client Robot B,
  such as connect to the Phoenix server, get the robot B's start and goal locations to be traversed.
  Call the respective functions from this module and others as needed.
  You may create extra helper functions as needed.
  """
  def main do
    {:ok, _response, channel} = Task4CClientRobotB.PhoenixSocketClient.connect_server()
    message =  Task4CClientRobotB.PhoenixSocketClient.receive_pos(channel)
    start_robot(message, channel)
  end

  def start_robot(message, channel) do
    IO.inspect("robotB  started moving")
    robotB_start = message["robotB_start"]
    goal_div_listB = message["goal_div_listB"]
    x_loc = String.to_integer(Enum.fetch!(robotB_start, 0))
    y_loc = String.to_atom(Enum.fetch!(robotB_start, 1))
    facing = String.to_atom(Enum.fetch!(robotB_start, 2))
    robot = %Task4CClientRobotB.Position{x: x_loc, y: y_loc, facing: facing}
    goal_locs = goal_div_listB
    stop(robot, goal_locs, channel)
  end

  @doc """
  Provide GOAL positions to the robot as given location of [(x1, y1),(x2, y2),..] and plan the path from START to these locations.
  Make a call to ToyRobot.PhoenixSocketClient.send_robot_status/2 to get the indication of obstacle presence ahead of the robot.
  """
  def stop(robot, goal_locs, channel) do
    i = 0
    move_goal(goal_locs, robot, channel, i)
  end

  def move_goal(goal_div_listB, robot, channel, i) when length(goal_div_listB) == i do
    #_is_obstacle = Task4CClientRobotB.PhoenixSocketClient.send_robot_status(channel, robot, 1)
    {:ok, robot}
  end

  def move_goal(goal_div_listB, robot, channel, i) when length(goal_div_listB) > i do
    goal = Enum.fetch!(goal_div_listB, i)
    goal_x = String.to_integer(Enum.fetch!(goal, 0))
    goal_y = String.to_atom(Enum.fetch!(goal, 1))
    goal_y_number = Map.get(@robot_map_y_atom_to_num, goal_y)
    IO.inspect(robot)
    IO.inspect(goal_x)
    IO.inspect(goal_y)
    IO.inspect(channel)
    robot = traverse(robot, goal_x, goal_y, channel)
    if Enum.fetch!(goal, 2) == "sowing" do
      move_goal(goal_div_listB, robot, channel, i+1)
    else
      robot = if goal_x > goal_y_number do
                deposition_x(robot)
              else
                deposition_y(robot)
              end
      move_goal(goal_div_listB, robot, channel, i+1)
    end
    #move_goal(goal_div_listB, robot, channel, i+1)
  end

  ###################### deposition is wrong , obstacle avoidance not taken into account ####################
  def deposition_y(%Task4CClientRobotB.Position{x: x, y: y, facing: facing} = robot) do
    IO.inspect(facing)
    case facing do
      :east ->
        left(robot)
      :west ->
        right(robot)
      :south ->
        robot = left(robot)
        left(robot)
    end
    diff_y = abs(6 - Map.get(@robot_map_y_atom_to_num, y))
    go_strt(robot, diff_y)
  end

  def deposition_x(%Task4CClientRobotB.Position{x: x, y: y, facing: facing} = robot) do
    IO.inspect(facing)
    case facing do
      :north ->
        right(robot)
      :west ->
        robot = right(robot)
        right(robot)
      :south ->
        left(robot)
    end
    diff_x = abs(6 - x)
    go_strt(robot, diff_x)
  end

  def go_strt(%Task4CClientRobotB.Position{x: x, y: y, facing: facing} = robot, 0) do
    robot
  end

  def go_strt(%Task4CClientRobotB.Position{x: x, y: y, facing: facing} = robot, diff) do
    move_check(robot)
    go_strt(robot, diff - 1)
  end

  defp traverse(%Task4CClientRobotB.Position{x: x, y: y, facing: facing} = robot, goal_x, goal_y, channel) when x == goal_x and y == goal_y do
    _is_obstacle = Task4CClientRobotB.PhoenixSocketClient.send_robot_status(channel, robot, 0)
    robot
  end

  defp traverse(%Task4CClientRobotB.Position{x: x, y: y, facing: facing} = robot, goal_x, goal_y, channel) do
    Process.sleep(200)
    IO.inspect("traverse to goal")
    is_obstacle_0 = Task4CClientRobotB.PhoenixSocketClient.send_robot_status(channel, robot, 0)

    robot = if is_obstacle_0 do
              obstacle_sequence(robot, channel)
            else
              x_direction = if goal_x > x do :east else :west end
              y_direction = if goal_y > y do :north else :south end
              cond do
                x != goal_x and facing != x_direction -> right(robot)
                x != goal_x and facing == x_direction -> move_check(robot)
                y != goal_y and facing != y_direction -> left(robot)
                y != goal_y and facing == y_direction -> move_check(robot)
                true -> IO.puts("No matching clause: x:#{x} y:#{y} F:#{facing} X-dir:#{x_direction} Y-dir:#{y_direction} Goal_X:#{goal_x} Goal_Y:#{goal_y}")
              end
            end
    traverse(robot, goal_x, goal_y, channel)
  end

  defp move_possible(%Task4CClientRobotB.Position{x: x, y: y, facing: facing} = _robot) do
    case {x, y, facing} do
      {_x, :e, :north} -> false
      {_x, :a, :south} -> false
      {1, _y, :west} -> false
      {5, _y, :east} -> false
      _ -> true
    end
  end

  defp left_until_free(robot, channel) do
    robot = left(robot)
    if Task4CClientRobotB.PhoenixSocketClient.send_robot_status(channel, robot, 0) or !move_possible(robot) do
      left_until_free(robot, channel)
    else
      robot
    end
  end

  defp obstacle_sequence(robot, channel) do
    robot = left_until_free(robot, channel)
    robot = move_check(robot)
    _ = Task4CClientRobotB.PhoenixSocketClient.send_robot_status(channel, robot, 0)
    robot = right(robot)
    if !Task4CClientRobotB.PhoenixSocketClient.send_robot_status(channel, robot, 0) and move_possible(robot) do
      move_check(robot)
    else
      obstacle_sequence(robot, channel)
    end
  end

  def move_check(robot) do
    robot = move(robot)
    #send(:init_toyrobotB, {:check_collision, robotA})
    robot
  end

  @doc """
  Provides the report of the robot's current position

  Examples:

      iex> {:ok, robot} = Task4CClientRobotB.place(2, :b, :west)
      iex> Task4CClientRobotB.report(robot)
      {2, :b, :west}
  """
  def report(%Task4CClientRobotB.Position{x: x, y: y, facing: facing} = _robot) do
    {x, y, facing}
  end

  @directions_to_the_right %{north: :east, east: :south, south: :west, west: :north}
  @doc """
  Rotates the robot to the right
  """
  def right(%Task4CClientRobotB.Position{facing: facing} = robot) do
    %Task4CClientRobotB.Position{robot | facing: @directions_to_the_right[facing]}
  end

  @directions_to_the_left Enum.map(@directions_to_the_right, fn {from, to} -> {to, from} end)
  @doc """
  Rotates the robot to the left
  """
  def left(%Task4CClientRobotB.Position{facing: facing} = robot) do
    %Task4CClientRobotB.Position{robot | facing: @directions_to_the_left[facing]}
  end

  @doc """
  Moves the robot to the north, but prevents it to fall
  """
  def move(%Task4CClientRobotB.Position{x: _, y: y, facing: :north} = robot) when y < @table_top_y do
    %Task4CClientRobotB.Position{ robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) + 1 end) |> elem(0)
    }
  end

  @doc """
  Moves the robot to the east, but prevents it to fall
  """
  def move(%Task4CClientRobotB.Position{x: x, y: _, facing: :east} = robot) when x < @table_top_x do
    %Task4CClientRobotB.Position{robot | x: x + 1}
  end

  @doc """
  Moves the robot to the south, but prevents it to fall
  """
  def move(%Task4CClientRobotB.Position{x: _, y: y, facing: :south} = robot) when y > :a do
    %Task4CClientRobotB.Position{ robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) - 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the west, but prevents it to fall
  """
  def move(%Task4CClientRobotB.Position{x: x, y: _, facing: :west} = robot) when x > 1 do
    %Task4CClientRobotB.Position{robot | x: x - 1}
  end

  @doc """
  Does not change the position of the robot.
  This function used as fallback if the robot cannot move outside the table
  """
  def move(robot), do: robot

  def failure do
    raise "Connection has been lost"
  end
end
