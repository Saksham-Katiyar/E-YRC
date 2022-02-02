defmodule CLI.ToyRobotA do
  # max x-coordinate of table top
  @table_top_x 5
  # max y-coordinate of table top
  @table_top_y :e
  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5}

  @doc """
  Places the robot to the default position of (1, A, North)

  Examples:

      iex> CLI.ToyRobotA.place
      {:ok, %CLI.Position{facing: :north, x: 1, y: :a}}
  """
  def place do
    {:ok, %CLI.Position{}}
  end

  def place(x, y, _facing) when x < 1 or y < :a or x > @table_top_x or y > @table_top_y do
    {:failure, "Invalid position"}
  end

  def place(_x, _y, facing)
  when facing not in [:north, :east, :south, :west]
  do
    {:failure, "Invalid facing direction"}
  end

  @doc """
  Places the robot to the provided position of (x, y, facing),
  but prevents it to be placed outside of the table and facing invalid direction.

  Examples:

      iex> CLI.ToyRobotA.place(1, :b, :south)
      {:ok, %CLI.Position{facing: :south, x: 1, y: :b}}

      iex> CLI.ToyRobotA.place(-1, :f, :north)
      {:failure, "Invalid position"}

      iex> CLI.ToyRobotA.place(3, :c, :north_east)
      {:failure, "Invalid facing direction"}
  """
  def place(x, y, facing) do
    # IO.puts String.upcase("A I'm placed at => #{x},#{y},#{facing}")
    {:ok, %CLI.Position{x: x, y: y, facing: facing}}
  end

  @doc """
  Provide START position to the robot as given location of (x, y, facing) and place it.
  """
  def start(x, y, facing) do
    ###########################
    ## complete this funcion ##
    ###########################
    place(x, y, facing)
  end

  def stop(_robot, goal_x, goal_y, _cli_proc_name) when goal_x < 1 or goal_y < :a or goal_x > @table_top_x or goal_y > @table_top_y do
    {:failure, "Invalid STOP position"}
  end

  @doc """
  Provide GOAL positions to the robot as given location of [(x1, y1),(x2, y2),..] and plan the path from START to these locations.
  Passing the CLI Server process name that will be used to send robot's current status after each action is taken.
  Spawn a process and register it with name ':client_toyrobotA' which is used by CLI Server to send an
  indication for the presence of obstacle ahead of robot's current position and facing.
  """
  def stop(robot, goal_locs, cli_proc_name) do
    ###########################
    ## complete this funcion ##
    ###########################
    Process.register(self(), :client_toyrobotA)

    robotA = robot
    closest_to_A = closest_goal(robotA, goal_locs)

    receive do
      {:move_A, robotB, goal_list, closest_to_B} ->
        if closest_to_A == closest_to_B do
          dist_A = distance(robotA, closest_to_A)
          dist_B = distance(robotB, closest_to_B)
          if dist_A > dist_B do
            goal_list = goal_list -- closest_to_B
            next_goal(robotA, goal_list, closest_to_B, cli_proc_name)
          else
            goal_list = goal_list--closest_to_A
            goal_x = String.to_integer(Enum.fetch!(closest_to_A, 0))
            goal_y = Map.get(@robot_map_y_atom_to_num, String.to_atom(Enum.fetch!(closest_to_A, 1)))
            traverse(robotA, goal_x, goal_y, goal_list, cli_proc_name)
          end
        else
          # goal_list = goal_list -- closest_to_B
          goal_list = goal_list -- closest_to_A
          goal_x = String.to_integer(Enum.fetch!(closest_to_A, 0))
          goal_y = Map.get(@robot_map_y_atom_to_num, String.to_atom(Enum.fetch!(closest_to_A, 1)))
          traverse(robotA, goal_x, goal_y, goal_list, cli_proc_name)
        end
    end


    # listen_first()
    # receive do
    #   {:move_A, message} ->
    #     IO.puts(message)
    # end
    # # listen_from_server()
    # send(:init_toyrobotB, {:move_B, "moving B"})

    # receive do
    #   {:move_A, message} ->
    #     IO.puts(message)
    # end

  end

  defp next_goal(robotA, goal_list, closest_to_B, cli_proc_name) when goal_list == [] and closest_to_B == [] do
    _ = send_robot_status(robotA, cli_proc_name)
    {:ok, robotA}
  end

  defp next_goal(robotA, goal_list, closest_to_B, cli_proc_name) when goal_list == [] and closest_to_B != [] do
    _ = send_robot_status(robotA, cli_proc_name)
    send(:init_toyrobotB, {:move_B, robotA, goal_list, []})
  end

  defp next_goal(robotA, goal_list, _closest_to_B, cli_proc_name) do
    closest_to_A = closest_goal(robotA, goal_list)
    goal_x = String.to_integer(Enum.fetch!(closest_to_A, 0))
    goal_y = Map.get(@robot_map_y_atom_to_num, String.to_atom(Enum.fetch!(closest_to_A, 1)))
    goal_list = goal_list -- closest_to_A
    traverse(robotA, goal_x, goal_y, goal_list, cli_proc_name)
  end

  defp traverse(%CLI.Position{x: x, y: y, facing: _facing} = robot, goal_x, goal_y, _goal_list, cli_proc_name) when x == goal_x and y == goal_y do
    _is_obstacle = send_robot_status(robot, cli_proc_name)
    {:ok, robot}
  end

  defp traverse(%CLI.Position{x: x, y: y, facing: facing} = robot, goal_x, goal_y, goal_list, cli_proc_name) do
    is_obstacle_0 = send_robot_status(robot, cli_proc_name)
    send(:init_toyrobotB, {:move_B, robot, goal_list, [Integer.to_string(goal_x), Atom.to_string(goal_y)]})

    robot = if is_obstacle_0 do
      obstacle_sequence(robot, cli_proc_name)
    else
      x_direction = if goal_x > x do :east else :west end
      y_direction = if goal_y > y do :north else :south end

      receive do
        {:move_A, _robotB, _new_goal_list, _closest_to_B} ->
          cond do
            x != goal_x and facing != x_direction -> right(robot)
            x != goal_x and facing == x_direction -> move(robot)
            y != goal_y and facing != y_direction -> left(robot)
            y != goal_y and facing == y_direction -> move(robot)
            true -> IO.puts("No matching clause: x:#{x} y:#{y} F:#{facing} X-dir:#{x_direction} Y-dir:#{y_direction} Goal_X:#{goal_x} Goal_Y:#{goal_y}")
          end
          # traverse(robot, goal_x, goal_y, new_goal_list, cli_proc_name)
      end
    end
    traverse(robot, goal_x, goal_y, goal_list, cli_proc_name)
  end

  defp move_possible(%CLI.Position{x: x, y: y, facing: facing} = _robot) do
    case {x, y, facing} do
      {_x, :e, :north} -> false
      {_x, :a, :south} -> false
      {1, _y, :west} -> false
      {5, _y, :east} -> false
      _ -> true
    end
  end

  defp left_until_free(robot, cli_proc_name) do
    robot = left(robot)
    if send_robot_status(robot, cli_proc_name) or !move_possible(robot) do
      left_until_free(robot, cli_proc_name)
    else
      robot
    end
  end

  defp obstacle_sequence(robot, cli_proc_name) do
    robot = left_until_free(robot, cli_proc_name)
    robot = move(robot)
    _ = send_robot_status(robot, cli_proc_name)
    robot = right(robot)
    if !send_robot_status(robot, cli_proc_name) and move_possible(robot) do
      move(robot)
    else
      obstacle_sequence(robot, cli_proc_name)
    end
  end


  defp distance(%CLI.Position{x: x, y: y, facing: facing} = robot, goal) do
    start_x = x
    start_y = Map.get(@robot_map_y_atom_to_num, y)
    goal_x = String.to_integer(Enum.fetch!(goal, 0))
    goal_y = Map.get(@robot_map_y_atom_to_num, String.to_atom(Enum.fetch!(goal, 1)))
    diff_x = abs(goal_x - start_x)
    diff_y = abs(goal_y - start_y)
    n = diff_x + diff_y
    n = cond do
      goal_x > start_x ->
        cond do
          facing == :north or facing == :south ->
            n+2
          facing == :west ->
            n+3
        end
      goal_x < start_x ->
        cond do
          facing == :north or facing == :south ->
            n+2
          facing == :east ->
            n+3
        end
      goal_x == start_x ->
        cond do
          facing == :east or facing == :west ->
            n+1
          (goal_y > start_y and facing == :south) or (goal_y < start_y and facing == :north) ->
            n+2
        end
    end
    n
  end

  defp closest_goal(robot, goal_list) do
    if Enum.empty?(goal_list) do
      []
    else
      closest = Enum.min_by(goal_list, fn goal -> distance(robot, goal) end)   # return ["3", "c"]
      closest
    end
  end


  @doc """
  Send Toy Robot's current status i.e. location (x, y) and facing
  to the CLI Server process after each action is taken.
  Listen to the CLI Server and wait for the message indicating the presence of obstacle.
  The message with the format: '{:obstacle_presence, < true or false >}'.
  """
  def send_robot_status(%CLI.Position{x: x, y: y, facing: facing} = _robot, cli_proc_name) do
    send(cli_proc_name, {:toyrobotA_status, x, y, facing})
    # IO.puts("Sent by Toy Robot Client: #{x}, #{y}, #{facing}")
    listen_from_server()
  end

  @doc """
  Listen to the CLI Server and wait for the message indicating the presence of obstacle.
  The message with the format: '{:obstacle_presence, < true or false >}'.
  """
  def listen_from_server() do
    receive do
      {:obstacle_presence, is_obs_ahead} ->
        is_obs_ahead
    end
  end

  @doc """
  Provides the report of the robot's current position

  Examples:

      iex> {:ok, robot} = CLI.ToyRobotA.place(2, :b, :west)
      iex> CLI.ToyRobotA.report(robot)
      {2, :b, :west}
  """
  def report(%CLI.Position{x: x, y: y, facing: facing} = _robot) do
    {x, y, facing}
  end

  @directions_to_the_right %{north: :east, east: :south, south: :west, west: :north}
  @doc """
  Rotates the robot to the right
  """
  def right(%CLI.Position{facing: facing} = robot) do
    %CLI.Position{robot | facing: @directions_to_the_right[facing]}
  end

  @directions_to_the_left Enum.map(@directions_to_the_right, fn {from, to} -> {to, from} end)
  @doc """
  Rotates the robot to the left
  """
  def left(%CLI.Position{facing: facing} = robot) do
    %CLI.Position{robot | facing: @directions_to_the_left[facing]}
  end

  @doc """
  Moves the robot to the north, but prevents it to fall
  """
  def move(%CLI.Position{x: _, y: y, facing: :north} = robot) when y < @table_top_y do
    %CLI.Position{robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) + 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the east, but prevents it to fall
  """
  def move(%CLI.Position{x: x, y: _, facing: :east} = robot) when x < @table_top_x do
    %CLI.Position{robot | x: x + 1}
  end

  @doc """
  Moves the robot to the south, but prevents it to fall
  """
  def move(%CLI.Position{x: _, y: y, facing: :south} = robot) when y > :a do
    %CLI.Position{robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) - 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the west, but prevents it to fall
  """
  def move(%CLI.Position{x: x, y: _, facing: :west} = robot) when x > 1 do
    %CLI.Position{robot | x: x - 1}
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
