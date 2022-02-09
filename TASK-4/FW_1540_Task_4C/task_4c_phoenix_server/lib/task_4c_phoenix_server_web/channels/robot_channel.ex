defmodule Task4CPhoenixServerWeb.RobotChannel do
  use Phoenix.Channel

  @doc """
  Handler function for any Client joining the channel with topic "robot:status".
  Subscribe to the topic named "robot:update" on the Phoenix Server using Endpoint.
  Reply or Acknowledge with socket PID received from the Client.
  """
  def join("robot:status", _params, socket) do
    IO.inspect("join 1called")
    Task4CPhoenixServerWeb.Endpoint.subscribe("robot:update")
    #Task4CPhoenixServerWeb.Endpoint.subscribe("robot:status")
    #Task4CPhoenixServerWeb.Endpoint.subscribe("robot:start")
    IO.inspect("join2 called")
    :ok = Phoenix.PubSub.subscribe(Task4CPhoenixServer.PubSub, "robot:start")
    IO.inspect("join called")
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
        case face_value do
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
      Task4CPhoenixServerWeb.Endpoint.broadcast!("robot:update", "obs_pos", obs_msg_pos)
    else
      {:ok}
    end

    # file object to write each action taken by each Robot (A as well as B)
    {:ok, out_file} = File.open("task_4c_output.txt", [:append])
    # write the robot actions to a text file
    IO.binwrite(out_file, "#{message["client"]} => #{message["x"]}, #{message["y"]}, #{message["face"]}\n")

    {:reply, {:ok, is_obs_ahead}, socket}
  end

  def handle_info(%{event: "robot_start_goal", payload: msg_start_goal, topic: "robot:start"}, socket) do
    #def handle_info(msg_start_goal, socket) do
    %{"robotA_start" => robotA_start, "robotB_start" => robotB_start, "goal_pos" => list_plants} = msg_start_goal
    IO.inspect("recived ddddddddddddddddddddddddddddddddddddddddddddddd")
    #Phoenix.Channel.push(socket, "start_posA", messageA)
    #Phoenix.Channel.push(socket, "start_posB", messageB)
    {:noreply, socket}
  end

end
