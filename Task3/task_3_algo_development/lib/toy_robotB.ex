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
  Spawn a process and register it with name ':client_toyrobotB' which is used by CLI Server to send an
  indication for the presence of obstacle ahead of robot's current position and facing.
  """
  def stop(%CLI.Position{x: x, y: y, facing: facing} = robot, goal_locs, cli_proc_name) do
    ###########################
    ## complete this funcion ##
    ###########################

    self_pid = self()
    pid=spawn(fn -> loop(self_pid) end)
    Process.register(pid, :client_toyrobotB)

    closest_to_B = closest_goal(robot, goal_locs) # returns ["4", "d"]

    send(:client_toyrobotA, {:move_A, robot, goal_locs, closest_to_B})

    # receive do
    #   {:move_B, message} ->
    #     IO.puts(message)
    # end

    # send(:client_toyrobotA, {:move_A, "moving A again"})

    # pid = self()
    # IO.puts(Process.alive?(self()))
    # Process.register(pid, :client_toyrobotB)
    # send(:client_toyrobotA, {:move_A, goal_locs})

    # IO.inspect(self())
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.puts("B")
    # IO.inspect(self())
  end

  defp steps(%CLI.Position{x: x, y: y, facing: facing} = _robot, goal) do
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
    closest = Enum.min_by(goal_list, fn goal -> steps(robot, goal) end)   # return ["3", "c"]
    closest
  end

  def loop(pid) do
    receive do
      {:obstacle_presence, is_obs_ahead} ->
        send(pid, {:obstacle_presence, is_obs_ahead})
        loop(pid)
        # code
    end
  end


  @doc """
  Send Toy Robot's current status i.e. location (x, y) and facing
  to the CLI Server process after each action is taken.
  Listen to the CLI Server and wait for the message indicating the presence of obstacle.
  The message with the format: '{:obstacle_presence, < true or false >}'.
  """
  def send_robot_status(%CLI.Position{x: x, y: y, facing: facing} = _robot, cli_proc_name) do
    send(cli_proc_name, {:toyrobotB_status, x, y, facing})
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
