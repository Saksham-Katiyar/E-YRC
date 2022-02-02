defmodule Task4CPhoenixServerWeb.RobotChannel do
  use Phoenix.Channel

  @doc """
  Handler function for any Client joining the channel with topic "robot:status".
  Subscribe to the topic named "robot:update" on the Phoenix Server using Endpoint.
  Reply or Acknowledge with socket PID received from the Client.
  """
  def join("robot:status", _params, socket) do
    Task4CPhoenixServerWeb.Endpoint.subscribe("robot:update")
    {:ok, socket}
  end

  @doc """
  Callback function for messages that are pushed to the channel with "robot:status" topic with an event named "new_msg".
  Receive the message from the Client, parse it to create another Map strictly of this format:
  %{"client" => < "robot_A" or "robot_B" >,  "left" => < left_value >, "bottom" => < bottom_value >, "face" => < face_value > }

  These values should be pixel locations for the robot's image to be displayed on the Dashboard
  corresponding to the various actions of the robot as recevied from the Client.

  Broadcast the created Map of pixel locations, so that the ArenaLive module can update
  the robot's image and location on the Dashboard as soon as it receives the new data.

  Based on the message from the Client, determine the obstacle's presence in front of the robot
  and return the boolean value in this format {:ok, < true OR false >}.

  If an obstacle is present ahead of the robot, then broadcast the pixel location of the obstacle to be displayed on the Dashboard.
  """
  def handle_in("new_msg", message, socket) do
    left_value =
      case message["x"] do
        1 -> 0
        2 -> 150
        3 -> 300
        4 -> 450
        5 -> 600
        6 -> 750
      end

    bottom_value =
      case message["y"] do
        "a" -> 0
        "b" -> 150
        "c" -> 300
        "d" -> 450
        "e" -> 600
        "f" -> 750
      end
    face_value = message["face"]
    client_robot = message["client"]
    msg_pos = %{"client" => client_robot,"left" => left_value, "bottom" => bottom_value, "face" => face_value}

    Task4CPhoenixServerWeb.Endpoint.broadcast("robot:update", "robot_pos", msg_pos)

    # determine the obstacle's presence in front of the robot and return the boolean value
    is_obs_ahead = Task4CPhoenixServerWeb.FindObstaclePresence.is_obstacle_ahead?(message["x"], message["y"], message["face"])
    if is_obs_ahead do
      obs_left_value =
        case face_value doicate live view and server in elixr
          "south" ->
            left_value
          "east" ->
            left_value + 75
          "west" ->
            left_value - 75
        end
      obs_bottom_value =
        case face_value do
          "north" ->
            bottom_value + 75
          "south" ->
            bottom_value - 75
          "east" ->
            bottom_value
          "west" ->
            bottom_value
        end
      obs_msg_pos = %{"obs" => "#{is_obs_ahead}", "left" => obs_left_value, "bottom" => obs_bottom_value, "face" => face_value}
      Task4CPhoenixServerWeb.Endpoint.broadcast("robot:update", "obs_pos", obs_msg_pos)
    else
      {:ok}
    end

    # file object to write each action taken by each Robot (A as well as B)
    {:ok, out_file} = File.open("task_4c_output.txt", [:append])
    # write the robot actions to a text file
    IO.binwrite(out_file, "#{message["client"]} => #{message["x"]}, #{message["y"]}, #{message["face"]}\n")

    {:reply, {:ok, is_obs_ahead}, socket}
  end

  def handle_info(%{"robotA_start" => robotA_start, "robotB_start" => robotB_start, "goal_pos" => list_plants} = data, socket) do
    goal_listA = shortest_path(robotA_start, list_plants)    # modify list with nearest obstacle first
    goal_listB = shortest_path(robotB_start, list_plants)    #  ["own_pos", "nearest_obs", "second_one".....]
    goal_div_listA = []
    goal_div_listB = []
    goal_div_list = goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB)    # goals divided among A and B
    goal_div_listA = Enum.fetch!(goal_div_list, 0)
    goal_div_listB = Enum.fetch!(goal_div_list, 1)
    ## push to the clinet
    {:noreply, socket}
  end

  # robot, goal_list -> new_list with nearest obstacle first
  def shortest_path(%CLI.Position{robotA_start, list_plants) do
    start = [Enum.fetch!(robotA_start, 0), Enum.fetch!(robotA_start, 1)]
    shortest_path = []
    shortest_path = List.insert_at(shortest_path, 0, start)
    closest_goal(start, list_plants, shortest_path)
  end

  # modify old_list -> new_list with nearest obstacle first
  def closest_goal(_start, [], new_list) do
    new_list
  end

  def closest_goal(start, goal_list, new_list) do
    closest_goal = Enum.min_by(goal_list, fn goal -> dist(start, goal) end)   # return ["3", "c"]
    goal_list = List.delete(goal_list, closest_goal)
    new_list = List.insert_at(new_list, 36, closest_goal)
    closest_goal(closest_goal, goal_list, new_list)
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

  def goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB) when length(goal_listA) <= 1 do
    [goal_div_listA, goal_div_listB]
  end

  def goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB) when length(goal_listA) == 2 do
    distA = dist(Enum.fetch!(goal_listA, 0), Enum.fetch!(goal_listA, 1))
    distB = dist(Enum.fetch!(goal_listB, 0), Enum.fetch!(goal_listB, 1))
      if distA <= distB do
        update_listA(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
      else
        update_listB(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
      end
  end

  def goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB) when length(goal_listA) > 2 do
    if Enum.fetch!(goal_listA, 1) != Enum.fetch!(goal_listB, 1) do
      distA = dist(Enum.fetch!(goal_listA, 0), Enum.fetch!(goal_listA, 1))
      distB = dist(Enum.fetch!(goal_listB, 0), Enum.fetch!(goal_listB, 1))
      cond do
        distA == distB ->
          goal_listA = List.delete_at(goal_listA, 0)
          goal_listB = List.delete_at(goal_listB, 0)
          goal_div_listA = List.insert_at(goal_div_listA, 36, Enum.fetch!(goal_listA, 0))
          goal_div_listB = List.insert_at(goal_div_listB, 36, Enum.fetch!(goal_listB, 0))
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
    goal_div_listA = List.insert_at(goal_div_listA, 36, Enum.fetch!(goal_listA, 0))
    goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
  end

  def update_listB(goal_listA, goal_listB, goal_div_listA, goal_div_listB) do
    goal_listA = List.delete(goal_listA, Enum.fetch!(goal_listB, 1))
    goal_listB = List.delete_at(goal_listB, 0)
    goal_div_listB = List.insert_at(goal_div_listB, 36, Enum.fetch!(goal_listB, 0))
    goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB)
  end


end
