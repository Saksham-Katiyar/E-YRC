defmodule Task4CClientRobotA.PhoenixSocketClient do

  alias PhoenixClient.{Socket, Channel, Message}

  @doc """
  Connect to the Phoenix Server URL (defined in config.exs) via socket.
  Once ensured that socket is connected, join the channel on the server with topic "robot:status".
  Get the channel's PID in return after joining it.

  NOTE:
  The socket will automatically attempt to connect when it starts.
  If the socket becomes disconnected, it will attempt to reconnect automatically.
  Please note that start_link is not synchronous,
  so you must wait for the socket to become connected before attempting to join a channel.
  Reference to above note: https://github.com/mobileoverlord/phoenix_client#usage

  You may refer: https://github.com/mobileoverlord/phoenix_client/issues/29#issuecomment-660518498
  """
  def connect_server do
    socket_opts = [
      url: "ws://localhost:4000/socket/websocket"
    ]

    {:ok, socket} = PhoenixClient.Socket.start_link(socket_opts)
    wait_until_connected(socket)
    IO.inspect("connected to server")
    {:ok, _response, channel} = PhoenixClient.Channel.join(socket, "robot:status")
  end

  defp wait_until_connected(socket) do
    if !PhoenixClient.Socket.connected?(socket) do
      Process.sleep(100)
      wait_until_connected(socket)
    end
  end

  @doc """
  Send Toy Robot's current status i.e. location (x, y) and facing
  to the channel's PID with topic "robot:status" on Phoenix Server with the event named "new_msg".

  The message to be sent should be a Map strictly of this format:
  %{"client": < "robot_A" or "robot_B" >,  "x": < x_coordinate >, "y": < y_coordinate >, "face": < facing_direction > }

  In return from Phoenix server, receive the boolean value < true OR false > indicating the obstacle's presence
  in this format: {:ok, < true OR false >}.
  Create a tuple of this format: '{:obstacle_presence, < true or false >}' as a return of this function.
  """
  # t = 1 indicates all goals of robotB reached

  def send_robot_status(channel, %Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot, goal_statusA) when goal_statusA == 1 do
    message = %{"client": "robot_A", "x": x, "y": y, "face": facing}
    ## %{"client": "robot_A", "x": 1, "y": "f", "face": "north"}

    ########### receive status of B and send status of A ################

    {:ok, is_obs_ahead} = PhoenixClient.Channel.push(channel, "new_msg", message)

    send_robot_status(channel, robot, goal_statusA)


  end

  def send_robot_status(channel, %Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot, goal_statusA) when goal_statusA == 0 do
    message = %{"client": "robot_A", "x": x, "y": y, "face": facing}
    ## %{"client": "robot_A", "x": 1, "y": "f", "face": "north"}
    {:ok, is_obs_ahead} = PhoenixClient.Channel.push(channel, "new_msg", message)
    IO.inspect("#{is_obs_ahead}")
    is_obs_ahead
  end

  def handle_in("start_posA", message, socket) do
    IO.inspect("handle in called waiting for msg from server")
    pid = spawn_link(fn -> loop(message) end)
    Process.register(pid, :client_toyrobotA)
    {:noreply, socket}
  end

  def loop(message) do
    IO.inspect("loop called")
    send(:toyrobotA, {:start_pos, message})
  end
  # def send_robot_status(channel, %Task4CClientRobotA.Position{x: x, y: y, facing: facing} = _robot) do
  #   message = %{"client": "robot_A", "x": x, "y": y, "face": facing}
  #   ## %{"client": "robot_A", "x": 1, "y": "f", "face": "north"}
  #   {:ok, is_obs_ahead} = PhoenixClient.Channel.push(channel, "new_msgA", message)
  #   is_obs_ahead
  # end


  ######################################################
  ## You may create extra helper functions as needed. ##
  ######################################################

end
