defmodule CLI.ToyRobotB do
  # max x-coordinate of table top
  @table_top_x 5
  # max y-coordinate of table top
  @table_top_y :e
  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5}

  @doc """
  Places the robot to the default position of (1, A, North)

  Examples:

      iex> CLI.ToyRobotB.place
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

      iex> CLI.ToyRobotB.place(1, :b, :south)
      {:ok, %CLI.Position{facing: :south, x: 1, y: :b}}

      iex> CLI.ToyRobotB.place(-1, :f, :north)
      {:failure, "Invalid position"}

      iex> CLI.ToyRobotB.place(3, :c, :north_east)
      {:failure, "Invalid facing direction"}
  """
  def place(x, y, facing) do
    # IO.puts String.upcase("B I'm placed at => #{x},#{y},#{facing}")
    {:ok, %CLI.Position{x: x, y: y, facing: facing}}
  end

  @doc """
  Provide START position to the robot as given location of (x, y, facing) and place it.
  """
  def start(x, y, facing) do
    place(x, y, facing)
  end

  def stop(_robot, goal_x, goal_y, _cli_proc_name) when goal_x < 1 or goal_y < :a or goal_x > @table_top_x or goal_y > @table_top_y do
    {:failure, "Invalid STOP position"}
  end

  @doc """
  Provide GOAL positions to the robot as given location of [(x1, y1),(x2, y2),..] and plan the path from START to these locations.
  Passing the CLI Server process name that will be used to send robot's current status after each action is taken.
  Spawn a process and register it with name ':client_toyrobotB' which is used by CLI Server to send an
  indication for the presence of obstacle ahead of robot's current position and facing.
  """
  def stop(robot, _goal_locs, cli_proc_name) do
    pid = spawn_link(fn -> loop() end)
    Process.register(pid, :client_toyrobotB)

    robotB = robot

    # kpid = spawn_link(fn -> loop_init() end)
    # Process.register(kpid, :status_toyrobotB)

    send(:client_toyrobotA, {:robotB_status_first, robotB})
    goal_div_listB =  receive do
                        {:goal_list_of_B, goal_div_listB} ->
                          goal_div_listB
                      end
    #IO.inspect(goal_div_listB)
    i = 0
    move_goal(goal_div_listB, robotB, cli_proc_name, i)
  end

  def move_goal(goal_div_listB, robotB, cli_proc_name, i) when length(goal_div_listB) == i do
    _is_obstacle = send_robot_status_true(robotB, cli_proc_name, 1)
    move_goal(goal_div_listB, robotB, cli_proc_name, i)
  end

  def move_goal(goal_div_listB, robotB, cli_proc_name, i) when length(goal_div_listB) > i do
    goal = Enum.fetch!(goal_div_listB, i)
    goal_x = String.to_integer(Enum.fetch!(goal, 0))
    goal_y = String.to_atom(Enum.fetch!(goal, 1))
    robotB = traverse(robotB, goal_x, goal_y, cli_proc_name)
    move_goal(goal_div_listB, robotB, cli_proc_name, i+1)
  end


  defp traverse(%CLI.Position{x: x, y: y, facing: _facing} = robot, goal_x, goal_y, cli_proc_name) when x == goal_x and y == goal_y do
    _is_obstacle = send_robot_status_true(robot, cli_proc_name, 0)
    robot
  end

  defp traverse(%CLI.Position{x: x, y: y, facing: facing} = robot, goal_x, goal_y, cli_proc_name) do
    is_obstacle_0 = send_robot_status_true(robot, cli_proc_name, 0)

    robot = if is_obstacle_0 do
              obstacle_sequence(robot, cli_proc_name)
            else
              x_direction = if goal_x > x do :east else :west end
              y_direction = if goal_y > y do :north else :south end
              cond do
                x != goal_x and facing != x_direction -> right(robot)
                x != goal_x and facing == x_direction -> move_check(robot, cli_proc_name)
                y != goal_y and facing != y_direction -> left(robot)
                y != goal_y and facing == y_direction -> move_check(robot, cli_proc_name)
                true -> IO.puts("No matching clause: x:#{x} y:#{y} F:#{facing} X-dir:#{x_direction} Y-dir:#{y_direction} Goal_X:#{goal_x} Goal_Y:#{goal_y}")
              end
            end
    traverse(robot, goal_x, goal_y, cli_proc_name)
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
    if send_robot_status_true(robot, cli_proc_name, 0) or !move_possible(robot) do
      left_until_free(robot, cli_proc_name)
    else
      robot
    end
  end

  defp obstacle_sequence(robot, cli_proc_name) do
    robot = left_until_free(robot, cli_proc_name)
    robot = move_check(robot, cli_proc_name)
    _ = send_robot_status_true(robot, cli_proc_name, 0)
    robot = right(robot)
    if !send_robot_status_true(robot, cli_proc_name, 0) and move_possible(robot) do
      move_check(robot, cli_proc_name)
    else
      obstacle_sequence(robot, cli_proc_name)
    end
  end

  def move_check(robotB, cli_proc_name) do
    next_robotB = move(robotB)
    # receive do
    #   {:check_collision, robotA} ->
    #     if robotA == next_robotB do
    #       _is_obs_ahead = send_robot_status_true(robotB, cli_proc_name, 0)
    #       #move_check(robotB, cli_proc_name)
    #     else
    #       next_robotB
    #     end
    # end
    next_robotB
  end


  def loop() do
    receive do
      {:obstacle_presence, is_obs_ahead} ->
        send(:init_toyrobotB, {:obstacle_presence, is_obs_ahead})
        loop()
    end
  end

  # def loop_init() do
  #   receive do
  #     {:obstacle_presence, is_obs_ahead} ->
  #       send(:init_toyrobotB, {:obstacle_presence, is_obs_ahead})
  #       loop()
  #   end
  # end

  @doc """
  Send Toy Robot's current status i.e. location (x, y) and facing
  to the CLI Server process after each action is taken.
  Listen to the CLI Server and wait for the message indicating the presence of obstacle.
  The message with the format: '{:obstacle_presence, < true or false >}'.
  """

  # t = 1 indicates all goals of robotB reached
  def send_robot_status_true(%CLI.Position{x: x, y: y, facing: facing} = _robot, cli_proc_name, goal_statusB) do
    send(:client_toyrobotA, {:robotB_status, goal_statusB})
    receive do
      {:robotA_status, _goal_statusA} ->
        send(cli_proc_name, {:toyrobotB_status, x, y, facing})
        listen_from_server()
    end
  end

  def send_robot_status(%CLI.Position{x: x, y: y, facing: facing} = _robot, cli_proc_name) do
    send(cli_proc_name, {:toyrobotB_status, x, y, facing})
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

      iex> {:ok, robot} = CLI.ToyRobotB.place(2, :b, :west)
      iex> CLI.ToyRobotB.report(robot)
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
