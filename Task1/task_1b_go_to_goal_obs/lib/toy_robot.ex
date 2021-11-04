defmodule ToyRobot do
  # max x-coordinate of table top
  @table_top_x 5
  # max y-coordinate of table top
  @table_top_y :e
  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5}

  @doc """
  Places the robot to the default position of (1, A, North)

  Examples:

      iex> ToyRobot.place
      {:ok, %ToyRobot.Position{facing: :north, x: 1, y: :a}}
  """
  def place do
    {:ok, %ToyRobot.Position{}}
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

      iex> ToyRobot.place(1, :b, :south)
      {:ok, %ToyRobot.Position{facing: :south, x: 1, y: :b}}

      iex> ToyRobot.place(-1, :f, :north)
      {:failure, "Invalid position"}

      iex> ToyRobot.place(3, :c, :north_east)
      {:failure, "Invalid facing direction"}
  """
  def place(x, y, facing) do
    {:ok, %ToyRobot.Position{x: x, y: y, facing: facing}}
  end

  @doc """
  Provide START position to the robot as given location of (x, y, facing) and place it.
  """
  def start(x, y, _facing) when x < 1 or y < :a or x > @table_top_x or y > @table_top_y do
    {:failure, "Invalid START position"}
  end

  def start(_x, _y, facing)
  when facing not in [:north, :east, :south, :west]
  do
    {:failure, "Invalid facing direction"}
  end

  def start(x, y, facing) do
    {:ok, %ToyRobot.Position{x: x, y: y, facing: facing}}
  end

  def stop(_robot, goal_x, goal_y, _cli_proc_name) when goal_x < 1 or goal_y < :a or goal_x > @table_top_x or goal_y > @table_top_y do
    {:failure, "Invalid STOP position"}
  end

  @doc """
  Provide STOP position to the robot as given location of (x, y) and plan the path from START to STOP.
  Passing the CLI Server process name that will be used to send robot's current status after each action is taken.
  Spawn a process and register it with name ':client_toyrobot' which is used by CLI Server to send an
  indication for the presence of obstacle ahead of robot's current position and facing.
  """
  @directions_to_the_opposite %{:north => :south, :south => :north, :east=> :west, :west=> :east}
  @directions_to_the_right %{north: :east, east: :south, south: :west, west: :north}
  @directions_to_the_left Enum.map(@directions_to_the_right, fn {from, to} -> {to, from} end)
  def stop(%ToyRobot.Position{x: _x, y: _y, facing: _facing} = robot, goal_x, goal_y, cli_proc_name) do
    self_pid=self()
    _pid=spawn(fn -> loop(self_pid) end)
    Process.register(self_pid, :client_toyrobot)
    obs_map=[]
    index=0
    {:ok, obs_map}=make_obsmap(obs_map,index)
    is_obstacle=send_robot_status(robot,cli_proc_name)
    obs_map=update_obs_map(robot, obs_map,is_obstacle)
    traverse(robot,obs_map, goal_x, goal_y, cli_proc_name)
  end
  def traverse(%ToyRobot.Position{x: x, y: y, facing: _facing} = robot, _obs_map, goal_x, goal_y, cli_proc_name) when x==goal_x and y==goal_y do
    {:ok, robot}
  end
  def traverse(%ToyRobot.Position{x: x, y: y, facing: _facing} = robot, obs_map, goal_x, goal_y, cli_proc_name) do

    goal_index=@robot_map_y_atom_to_num[goal_y]*5+goal_x-6
    position_index=@robot_map_y_atom_to_num[y]*5+x-6
    shortest_path=[position_index]
    index=0
    goal_position_index=Enum.at(shortest_path, index)
    shortest_path=make_shortest_path(shortest_path,goal_index,index,obs_map,goal_position_index)
    # IO.puts Enum.at(shortest_path,0)
    # IO.puts Enum.at(shortest_path,1)
    # IO.puts Enum.at(shortest_path,2)
    # IO.puts Enum.at(shortest_path,3)
    # IO.puts Enum.at(shortest_path,4)
    # IO.puts Enum.at(shortest_path,5)
    # IO.puts Enum.at(shortest_path,6)
    {robot,obs_map}=move_on_shortest_path(robot,shortest_path, index, cli_proc_name, obs_map)
    traverse(robot,obs_map, goal_x, goal_y, cli_proc_name)
  end
  def find_shortest_path(shortest_path,index,li) when index==0 do
    li=List.insert_at(li, 0, Enum.at(shortest_path,index))
    li
  end
  def find_shortest_path(shortest_path,index,li) do
    li=List.insert_at(li, 0, Enum.at(shortest_path,index))
    find_shortest_path(shortest_path,trunc((index-1)/4),li)
  end
  def make_shortest_path(shortest_path,goal_index,index,_obs_map,goal_position_index) when goal_position_index==goal_index do
    li=[]
    find_shortest_path(shortest_path,index,li)
  end
  def make_shortest_path(shortest_path,goal_index,index,obs_map, _goal_position_index) do
    shortest_path=shortest_path++find_neighbour_indexes(Enum.at(shortest_path,index),obs_map)
    goal_position_index=Enum.at(shortest_path, index+1)
    make_shortest_path(shortest_path,goal_index,index+1,obs_map, goal_position_index)
  end
  def find_neighbour_indexes(position_index,obs_map) do
    x=rem(position_index,5)+1
    y=trunc(position_index/5)+1
    neighbour_indexes=if position_index==-1 do
                        [-1,-1,-1,-1]
                      else
                        neighbour_indexes=[]
                        neighbour_indexes=if position_index<20 and Enum.at(obs_map,(y*5+x+14))!=1 do
                                            List.insert_at(neighbour_indexes, 0, position_index+5)
                                          else
                                            List.insert_at(neighbour_indexes, 0, -1)
                                          end
                        neighbour_indexes=if rem(position_index+1,5)!=0 and Enum.at(obs_map,(y*4+x-5))!=1 do
                                            List.insert_at(neighbour_indexes, 1, position_index+1)
                                          else
                                            List.insert_at(neighbour_indexes, 1, -1)
                                          end
                        neighbour_indexes=if position_index>4 and Enum.at(obs_map,(y*5+x+9))!=1 do
                                            List.insert_at(neighbour_indexes, 2, position_index-5)
                                          else
                                            List.insert_at(neighbour_indexes, 2, -1)
                                          end
                        neighbour_indexes=if rem(position_index,5)!=0 and Enum.at(obs_map,(y*4+x-6))!=1 do
                                            List.insert_at(neighbour_indexes, 3, position_index-1)
                                          else
                                            List.insert_at(neighbour_indexes, 3, -1)
                                          end
                        neighbour_indexes
                      end
    neighbour_indexes
  end
  def move_on_shortest_path(%ToyRobot.Position{x: _x, y: _y, facing: _facing} = robot, shortest_path, index, _cli_proc_name, obs_map) when index==length(shortest_path)-1 do
    {robot,obs_map}
  end
  def move_on_shortest_path(%ToyRobot.Position{x: _x, y: _y, facing: _facing} = robot, shortest_path, index, cli_proc_name, obs_map) do
    {robot,obs_map,is_obstacle}=move_to_next_index(robot,Enum.at(shortest_path,index),Enum.at(shortest_path,index+1),cli_proc_name,obs_map)
    {robot,obs_map}=if is_obstacle==false do
                      move_on_shortest_path(robot,shortest_path, index+1, cli_proc_name, obs_map)
                    else
                      {robot,obs_map}
                    end

    {robot,obs_map}
  end
  def move_to_next_index(%ToyRobot.Position{x: _x, y: _y, facing: facing} = robot, index_0, index_1, cli_proc_name,obs_map) do
    direction=cond do
                index_1==index_0+5 -> :north
                index_1==index_0+1 -> :east
                index_1==index_0-5 -> :south
                index_1==index_0-1 -> :west
              end

    {robot, is_obstacle, obs_map}= if @directions_to_the_right[facing]==direction do
      robot=right(robot)
      is_obstacle=send_robot_status(robot,cli_proc_name)
      obs_map=update_obs_map(robot, obs_map, is_obstacle)
      {robot, is_obstacle, obs_map}
    else
      {robot, is_obstacle, obs_map}= if @directions_to_the_left[facing]==direction do
        robot=left(robot)
        is_obstacle=send_robot_status(robot,cli_proc_name)
        obs_map=update_obs_map(robot, obs_map, is_obstacle)
        {robot, is_obstacle, obs_map}
      else
        {robot, is_obstacle, obs_map}= if @directions_to_the_opposite[facing]==direction do
          robot=right(robot)
          _is_obstacle=send_robot_status(robot,cli_proc_name)
          robot=right(robot)
          is_obstacle=send_robot_status(robot,cli_proc_name)
          obs_map=update_obs_map(robot, obs_map, is_obstacle)
          {robot, is_obstacle, obs_map}
        else
          {robot, false, obs_map}
        end
      end
    end
    robot=if is_obstacle==false do
            move(robot)
          else
            robot
          end
    {is_obstacle, obs_map}= if is_obstacle==false do
                              is_obstacle=send_robot_status(robot,cli_proc_name)
                              obs_map=update_obs_map(robot, obs_map, is_obstacle)
                              {is_obstacle, obs_map}
                            else
                              {is_obstacle, obs_map}
                            end
    {robot, obs_map, is_obstacle}
  end
  def update_obs_map(%ToyRobot.Position{x: x, y: y, facing: facing} = _robot, obs_map, is_obstacle) do
    obs_map=if is_obstacle==true do
              obs_map=if facing==:east do
                        index=(@robot_map_y_atom_to_num[y])*4+x-5
                        {_,obs_map}=List.pop_at(obs_map,index)
                        obs_map=List.insert_at(obs_map,index,1)
                        obs_map
                      else
                        obs_map
                      end
              obs_map=if facing==:west do
                        index=(@robot_map_y_atom_to_num[y])*4+x-6
                        {_,obs_map}=List.pop_at(obs_map,index)
                        obs_map=List.insert_at(obs_map,index,1)
                        obs_map
                      else
                        obs_map
                      end
              obs_map=if facing==:north do
                        index=(@robot_map_y_atom_to_num[y])*5+x+14
                        {_,obs_map}=List.pop_at(obs_map,index)
                        obs_map=List.insert_at(obs_map,index,1)
                        obs_map
                      else
                        obs_map
                      end
              obs_map=if facing==:south do
                        index=(@robot_map_y_atom_to_num[y])*5+x+9
                        {_,obs_map}=List.pop_at(obs_map,index)
                        obs_map=List.insert_at(obs_map,index,1)
                        obs_map
                      else
                        obs_map
                      end
              obs_map
            else
              obs_map
            end
    obs_map
  end
  def make_obsmap(obs_map, index) when index==40 do
    {:ok, obs_map}
  end
  def make_obsmap(obs_map, index) do
    obs_map=List.insert_at(obs_map,index,0)
    make_obsmap(obs_map,index+1)
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
  def send_robot_status(%ToyRobot.Position{x: x, y: y, facing: facing} = _robot, cli_proc_name) do
    send(cli_proc_name, {:toyrobot_status, x, y, facing})
    # IO.puts("Sent by Toy Robot Client: #{x}, #{y}, #{facing}")
    listen_from_server()
  end

  @doc """
  Listen to the CLI Server and wait for the message indicating the presence of obstacle.
  The message with the format: '{:obstacle_presence, < true or false >}'.
  """


  def listen_from_server() do
    receive do
      {:obstacle_presence, is_obs_ahead} -> is_obs_ahead
    end
  end

  @doc """
  Provides the report of the robot's current position

  Examples:

      iex> {:ok, robot} = ToyRobot.place(2, :b, :west)
      iex> ToyRobot.report(robot)
      {2, :b, :west}
  """
  def report(%ToyRobot.Position{x: x, y: y, facing: facing} = _robot) do
    {x, y, facing}
  end

  @directions_to_the_right %{north: :east, east: :south, south: :west, west: :north}
  @doc """
  Rotates the robot to the right
  """
  def right(%ToyRobot.Position{facing: facing} = robot) do
    %ToyRobot.Position{robot | facing: @directions_to_the_right[facing]}
  end

  @directions_to_the_left Enum.map(@directions_to_the_right, fn {from, to} -> {to, from} end)
  @doc """
  Rotates the robot to the left
  """
  def left(%ToyRobot.Position{facing: facing} = robot) do
    %ToyRobot.Position{robot | facing: @directions_to_the_left[facing]}
  end

  @doc """
  Moves the robot to the north, but prevents it to fall
  """
  def move(%ToyRobot.Position{x: _, y: y, facing: :north} = robot) when y < @table_top_y do
    %ToyRobot.Position{robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) + 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the east, but prevents it to fall
  """
  def move(%ToyRobot.Position{x: x, y: _, facing: :east} = robot) when x < @table_top_x do
    %ToyRobot.Position{robot | x: x + 1}
  end

  @doc """
  Moves the robot to the south, but prevents it to fall
  """
  def move(%ToyRobot.Position{x: _, y: y, facing: :south} = robot) when y > :a do
    %ToyRobot.Position{robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) - 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the west, but prevents it to fall
  """
  def move(%ToyRobot.Position{x: x, y: _, facing: :west} = robot) when x > 1 do
    %ToyRobot.Position{robot | x: x - 1}
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
