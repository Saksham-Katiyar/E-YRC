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
  def stop(%CLI.Position{x: x, y: y, facing: facing} = robot, goal_locs, cli_proc_name) do
    Process.register(self(), :client_toyrobotA)

    robotA = robot
    robotB =  receive do
                {:robotB_status_first, robotB} ->
                  robotB
              end
    goal_div_list = callback(robotA, robotB, goal_locs, cli_proc_name)
    #IO.inspect(goal_div_list)
    goal_div_listA = Enum.fetch!(goal_div_list, 0)
    goal_div_listB = Enum.fetch!(goal_div_list, 1)
    send(:init_toyrobotB, {:goal_list_of_B,  goal_div_listB})
    i = 0
    move_goal(goal_div_listA, robotA, cli_proc_name, i)
  end

  def move_goal(goal_div_listA, robotA, cli_proc_name, i) when length(goal_div_listA) == i do
    _is_obstacle = send_robot_status_true(robotA, cli_proc_name, 1)
    move_goal(goal_div_listA, robotA, cli_proc_name, i)
  end

  def move_goal(goal_div_listA, robotA, cli_proc_name, i) when length(goal_div_listA) > i do
    goal = Enum.fetch!(goal_div_listA, i)
    goal_x = String.to_integer(Enum.fetch!(goal, 0))
    goal_y = String.to_atom(Enum.fetch!(goal, 1))
    robotA = traverse(robotA, goal_x, goal_y, cli_proc_name)
    move_goal(goal_div_listA, robotA, cli_proc_name, i+1)
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
                x != goal_x and facing == x_direction -> move_check(robot)
                y != goal_y and facing != y_direction -> left(robot)
                y != goal_y and facing == y_direction -> move_check(robot)
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
    robot = move_check(robot)
    _ = send_robot_status_true(robot, cli_proc_name, 0)
    robot = right(robot)
    if !send_robot_status_true(robot, cli_proc_name, 0) and move_possible(robot) do
      move_check(robot)
    else
      obstacle_sequence(robot, cli_proc_name)
    end
  end

  def move_check(robotA) do
    robotA = move(robotA)
    send(:init_toyrobotB, {:check_collision, robotA})
    robotA
  end

  def callback(robotA, robotB, goal_locs, _cli_proc_name) do
    goal_list = String.split("#{goal_locs}", "", trim: true)  # list  ["1", "a", "3", "c"]
    mod_goal_list = []
    mod_goal_list = modify_list(goal_list, mod_goal_list)   # modify list [["1", "a"], ["1", "a"]]

    goal_listA = shortest_path(robotA, mod_goal_list)    # modify list with nearest obstacle first
    #IO.inspect(goal_listA)
    goal_listB = shortest_path(robotB, mod_goal_list)    #  ["own_pos", "nearest_obs", "second_one".....]
    #IO.inspect(goal_listB)

    goal_div_listA = []
    goal_div_listB = []
    goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB)    # goals divided among A and B
  end


  # modify ["1", "a", "3", "c"] -> [["1", "a"], ["3", "c"]]
  def modify_list([], new_list) do
    new_list
  end

  def modify_list(goal_list, new_list) when goal_list != [] do
    list = []
    list = List.insert_at(list, 0, hd(goal_list))
    goal_list = List.delete_at(goal_list, 0)
    list = List.insert_at(list, 1, hd(goal_list))
    goal_list = List.delete_at(goal_list, 0)
    new_list = List.insert_at(new_list, 25, list)
    modify_list(goal_list, new_list)
  end


  def goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB) when length(goal_listA) <= 1 do
    # IO.inspect(goal_listA)
    # IO.inspect(goal_listB)
    # IO.inspect(goal_div_listA)
    # IO.inspect(goal_div_listB)
    [goal_div_listA, goal_div_listB]
  end

  def goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB) when length(goal_listA) == 2 do
    # IO.inspect(goal_listA)
    # IO.inspect(goal_listB)
    # IO.inspect(goal_div_listA)
    # IO.inspect(goal_div_listB)
    distA = dist(Enum.fetch!(goal_listA, 0), Enum.fetch!(goal_listA, 1))
    distB = dist(Enum.fetch!(goal_listB, 0), Enum.fetch!(goal_listB, 1))
      if distA <= distB do
        update_listA(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
      else
        update_listB(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
      end
  end

  def goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB) when length(goal_listA) > 2 do
    # IO.inspect(goal_listA)
    # IO.inspect(goal_listB)
    # IO.inspect(goal_div_listA)
    # IO.inspect(goal_div_listB)
    if Enum.fetch!(goal_listA, 1) != Enum.fetch!(goal_listB, 1) do
      distA = dist(Enum.fetch!(goal_listA, 0), Enum.fetch!(goal_listA, 1))
      distB = dist(Enum.fetch!(goal_listB, 0), Enum.fetch!(goal_listB, 1))
      cond do
        distA == distB ->
          goal_listA = List.delete_at(goal_listA, 0)
          goal_listB = List.delete_at(goal_listB, 0)
          goal_div_listA = List.insert_at(goal_div_listA, 25, Enum.fetch!(goal_listA, 0))
          goal_div_listB = List.insert_at(goal_div_listB, 25, Enum.fetch!(goal_listB, 0))
          goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
        distA < distB ->
          update_listA(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
        distA > distB ->
          update_listB(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
      end
    else
      distA = dist(Enum.fetch!(goal_listA, 0), Enum.fetch!(goal_listA, 1))
      distB = dist(Enum.fetch!(goal_listB, 0), Enum.fetch!(goal_listB, 1))
      cond do
        distA > distB ->
          #IO.inspect("2")
          update_listB(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
        distA < distB ->
          #IO.inspect("1")
          update_listA(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
        distA == distB ->
          #IO.inspect("3")
          distA = dist(Enum.fetch!(goal_listA, 0), Enum.fetch!(goal_listA, 2))
          distB = dist(Enum.fetch!(goal_listB, 0), Enum.fetch!(goal_listB, 2))
          cond do
            distA > distB ->
              #IO.inspect("2")
              update_listA(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
            distA < distB ->
              #IO.inspect("1")
              update_listB(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
            distA == distB ->
              i = 2
              if length(goal_listA) <= 3 do
                update_listA(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
              else
                adding_goals(goal_listA, goal_listB, goal_div_listA, goal_div_listB, i)
              end
          end
      end
    end
  end

  def adding_goals(goal_listA, goal_listB, goal_div_listA, goal_div_listB, i) when length(goal_listA) == i+1  do
    update_listA(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
  end

  def adding_goals(goal_listA, goal_listB, goal_div_listA, goal_div_listB, i) do
    distA = dist(Enum.fetch!(goal_listA, i), Enum.fetch!(goal_listA, i+1))
    distB = dist(Enum.fetch!(goal_listB, i), Enum.fetch!(goal_listB, i+1))
    cond do
      distA > distB ->
        update_listA(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
      distA < distB ->
        update_listB(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
      distA == distB ->
        if i >= length(goal_listA) - 1 do                   #
          update_listA(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
        else
          adding_goals(goal_listA, goal_listB, goal_div_listA, goal_div_listB, i+1)
        end
    end
  end


  def update_listA(goal_listA, goal_listB, goal_div_listA, goal_div_listB) do
    goal_listB = List.delete(goal_listB, Enum.fetch!(goal_listA, 1))
    goal_listA = List.delete_at(goal_listA, 0)
    goal_div_listA = List.insert_at(goal_div_listA, 25, Enum.fetch!(goal_listA, 0))
    goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
  end

  def update_listB(goal_listA, goal_listB, goal_div_listA, goal_div_listB) do
    goal_listA = List.delete(goal_listA, Enum.fetch!(goal_listB, 1))
    goal_listB = List.delete_at(goal_listB, 0)
    goal_div_listB = List.insert_at(goal_div_listB, 25, Enum.fetch!(goal_listB, 0))
    goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
  end


  # get distance ["1", "a"], ["3", "c"] -> Number
  def dist(start, goal) do
    start_x = String.to_integer(Enum.fetch!(start, 0))
    goal_x = String.to_integer(Enum.fetch!(goal, 0))
    start_y = Map.get(@robot_map_y_atom_to_num, String.to_atom(Enum.fetch!(start, 1)))
    goal_y = Map.get(@robot_map_y_atom_to_num, String.to_atom(Enum.fetch!(goal, 1)))
    diff_x = abs(goal_x - start_x)
    diff_y = abs(goal_y - start_y)
    diff_x + diff_y
  end


  # modify old_list -> new_list with nearest obstacle first
  def closest_goal(_start, [], new_list) do
    new_list
  end

  def closest_goal(start, goal_list, new_list) do
    closest_goal = Enum.min_by(goal_list, fn goal -> dist(start, goal) end)   # return ["3", "c"]
    goal_list = List.delete(goal_list, closest_goal)
    new_list = List.insert_at(new_list, 25, closest_goal)
    closest_goal(closest_goal, goal_list, new_list)
  end


  # robot, goal_list -> new_list with nearest obstacle first
  def shortest_path(%CLI.Position{x: x, y: y, facing: _facing} = _robot, goal_list) do
    start = ["#{x}", "#{y}"]
    shortest_path = []
    shortest_path = List.insert_at(shortest_path, 0, start)
    closest_goal(start, goal_list, shortest_path)
  end


  @doc """
  Send Toy Robot's current status i.e. location (x, y) and facing
  to the CLI Server process after each action is taken.
  Listen to the CLI Server and wait for the message indicating the presence of obstacle.
  The message with the format: '{:obstacle_presence, < true or false >}'.
  """

  # t = 1 indicates all goals of robotB reached
  def send_robot_status_true(%CLI.Position{x: x, y: y, facing: facing} = robotA, cli_proc_name, goal_statusA) do
    receive do
      {:robotB_status, goal_statusB} ->
        if goal_statusA + goal_statusB == 2 do
          receive do
            {:message_type, value} ->
              value
          end
        else
          send(cli_proc_name, {:toyrobotA_status, x, y, facing})
          is_obs_ahead = listen_from_server()
          send(:init_toyrobotB, {:robotA_status, goal_statusA})
          is_obs_ahead
        end
    end
  end

  def send_robot_status(%CLI.Position{x: x, y: y, facing: facing} = _robot, cli_proc_name) do
    send(cli_proc_name, {:toyrobotA_status, x, y, facing})
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
