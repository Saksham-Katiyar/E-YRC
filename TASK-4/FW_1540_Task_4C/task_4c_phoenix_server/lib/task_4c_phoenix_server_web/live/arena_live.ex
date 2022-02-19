defmodule Task4CPhoenixServerWeb.ArenaLive do
  use Task4CPhoenixServerWeb,:live_view
  require Logger

  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5, :f => 6}

  @doc """
  Mount the Dashboard when this module is called with request
  for the Arena view from the client like browser.
  Subscribe to the "robot:update" topic using Endpoint.
  Subscribe to the "timer:update" topic as PubSub.
  Assign default values to the variables which will be updated
  when new data arrives from the RobotChannel module.
  """
  def mount(_params, _session, socket) do

    Task4CPhoenixServerWeb.Endpoint.subscribe("robot:update")
    :ok = Phoenix.PubSub.subscribe(Task4CPhoenixServer.PubSub, "timer:update")
    #:ok = Phoenix.PubSub.subscribe(Task4CPhoenixServer.PubSub, "robot:start")
    #Task4CPhoenixServerWeb.Endpoint.subscribe("robot:start")

    socket = assign(socket, :img_robotA, "robot_facing_north.png")
    socket = assign(socket, :bottom_robotA, 0)
    socket = assign(socket, :left_robotA, 0)
    socket = assign(socket, :robotA_start, "")
    socket = assign(socket, :robotA_goals, [])

    socket = assign(socket, :img_robotB, "robot_facing_south.png")
    socket = assign(socket, :bottom_robotB, 750)
    socket = assign(socket, :left_robotB, 750)
    socket = assign(socket, :robotB_start, "")
    socket = assign(socket, :robotB_goals, [])

    socket = assign(socket, :obstacle_pos, MapSet.new())
    socket = assign(socket, :timer_tick, 300)

    {:ok,socket}

  end

  @doc """
  Render the Grid with the coordinates and robot's location based
  on the "img_robotA" or "img_robotB" variable assigned in the mount/3 function.
  This function will be dynamically called when there is a change
  in the values of any of these variables =>
  "img_robotA", "bottom_robotA", "left_robotA", "robotA_start", "robotA_goals",
  "img_robotB", "bottom_robotB", "left_robotB", "robotB_start", "robotB_goals",
  "obstacle_pos", "timer_tick"
  """
  def render(assigns) do

    ~H"""
    <div id="dashboard-container">

      <div class="grid-container">
        <div id="alphabets">
          <div> A </div>
          <div> B </div>
          <div> C </div>
          <div> D </div>
          <div> E </div>
          <div> F </div>
        </div>

        <div class="board-container">
          <div class="game-board">
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
          </div>

          <%= for obs <- @obstacle_pos do %>
            <img  class="obstacles"  src="/images/stone.png" width="50px" style={"bottom: #{elem(obs,1)}px; left: #{elem(obs,0)}px"}>
          <% end %>

          <div class="robot-container" style={"bottom: #{@bottom_robotA}px; left: #{@left_robotA}px"}>
            <img id="robotA" src={"/images/#{@img_robotA}"} style="height:70px;">
          </div>

          <div class="robot-container" style={"bottom: #{@bottom_robotB}px; left: #{@left_robotB}px"}>
            <img id="robotB" src={"/images/#{@img_robotB}"} style="height:70px;">
          </div>

        </div>

        <div id="numbers">
          <div> 1 </div>
          <div> 2 </div>
          <div> 3 </div>
          <div> 4 </div>
          <div> 5 </div>
          <div> 6 </div>
        </div>

      </div>
      <div id="right-container">

        <div class="timer-card">
          <label style="text-transform:uppercase;width:100%;font-weight:bold;text-align:center" >Timer</label>
            <p id="timer" ><%= @timer_tick %></p>
        </div>

        <div class="goal-card">
          <div style="text-transform:uppercase;width:100%;font-weight:bold;text-align:center" > Goal positions </div>
          <div style="display:flex;flex-flow:wrap;width:100%">
            <div style="width:50%">
              <label>Robot A</label>
              <%= for i <- @robotA_goals do %>
                <div><%= i %></div>
              <% end %>
            </div>
            <div  style="width:50%">
              <label>Robot B</label>
              <%= for i <- @robotB_goals do %>
              <div><%= i %></div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="position-card">
          <div style="text-transform:uppercase;width:100%;font-weight:bold;text-align:center"> Start Positions </div>
          <form phx-submit="start_clock" style="width:100%;display:flex;flex-flow:row wrap;">
            <div style="width:100%;padding:10px">
              <label>Robot A</label>
              <input name="robotA_start" style="background-color:white;" value={"#{@robotA_start}"}>
            </div>
            <div style="width:100%; padding:10px">
              <label>Robot B</label>
              <input name="robotB_start" style="background-color:white;" value={"#{@robotB_start}"}>
            </div>

            <button  id="start-btn" type="submit">
              <svg xmlns="http://www.w3.org/2000/svg" style="height:30px;width:30px;margin:auto" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" />
              </svg>
            </button>

            <button phx-click="stop_clock" id="stop-btn" type="button">
              <svg xmlns="http://www.w3.org/2000/svg" style="height:30px;width:30px;margin:auto" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8 7a1 1 0 00-1 1v4a1 1 0 001 1h4a1 1 0 001-1V8a1 1 0 00-1-1H8z" clip-rule="evenodd" />
              </svg>
            </button>
          </form>
        </div>

      </div>

    </div>
    """

  end

  @doc """
  Handle the event "start_clock" triggered by clicking
  the PLAY button on the dashboard.
  """
  def handle_event("start_clock", data, socket) do
    socket = assign(socket, :robotA_start, data["robotA_start"])
    socket = assign(socket, :robotB_start, data["robotB_start"])
    Task4CPhoenixServerWeb.Endpoint.broadcast("timer:start", "start_timer", %{})

    robotA_start = String.split(data["robotA_start"], ",")  # ["1", " b", " north"]
    robotB_start = String.split(data["robotB_start"], ",")

    plants_data = File.read!("Plant_Positions.csv")
    list_plants = plants_data |> String.trim |> String.split("\n")
    list_plants = Enum.map(list_plants, fn params -> String.split(params, ",") end)
    list_plants = list_plants -- [["Sowing", "Weeding"]]
    ########### list plants need to be modified ##########
    list_plants = [["2", "b"], ["4", "c"], ["5", "f"]]

    robotA_start_loc = List.delete_at(robotA_start, 2)
    robotB_start_loc = List.delete_at(robotB_start, 2)
    goal_listA = shortest_path(robotA_start_loc, list_plants)    # modify list with nearest obstacle first
    goal_listB = shortest_path(robotB_start_loc, list_plants)    #  ["own_pos", "nearest_obs", "second_one".....]
    goal_div_listA = []
    goal_div_listB = []
    goal_div_list = goal_division(goal_listA, goal_listB, goal_div_listA, goal_div_listB)    # goals divided among A and B
    goal_div_listA = Enum.fetch!(goal_div_list, 0)
    goal_div_listB = Enum.fetch!(goal_div_list, 1)

    socket = assign(socket, :robotA_goals, goal_div_listA)
    socket = assign(socket, :robotB_goals, goal_div_listB)

    #messageA = %{"robotA_start" => robotA_start, "goal_div_listA" => goal_div_listA}
    #messageB = %{"robotB_start" => robotB_start, "goal_div_listB" => goal_div_listB}
    msg_start_goal = %{"robotA_start" => robotA_start, "robotB_start" => robotB_start, "goalA" => goal_div_listA, "goalB" => goal_div_listB}
  
    #:ok = Phoenix.PubSub.subscribe(Task4CPhoenixServer.PubSub, "robot:start")
    #:ok = Phoenix.PubSub.broadcast(Task4CPhoenixServer.PubSub, "robot:start", msg_start_goal)

    Task4CPhoenixServerWeb.Endpoint.broadcast!("robot:start", "robot_start_goal", msg_start_goal)

    #list_sowing = Enum.map(list_plants, fn params -> String.to_integer(hd(params)) end)
    #list_weeding = Enum.map(list_plants, fn params -> String.to_integer(hd(tl(params))) end)


    #################################
    ## edit the function if needed ##
    #################################

    {:noreply, socket}

  end

  @doc """
  Handle the event "stop_clock" triggered by clicking
  the STOP button on the dashboard.
  """
  def handle_event("stop_clock", _data, socket) do

    Task4CPhoenixServerWeb.Endpoint.broadcast("timer:stop", "stop_timer", %{})

    #################################
    ## edit the function if needed ##
    #################################

    {:noreply, socket}

  end

  @doc """
  Callback function to handle incoming data from the Timer module
  broadcasted on the "timer:update" topic.
  Assign the value to variable "timer_tick" for each countdown.
  """
  def handle_info(%{event: "update_timer_tick", payload: timer_data, topic: "timer:update"}, socket) do

    Logger.info("Timer tick: #{timer_data.time}")
    socket = assign(socket, :timer_tick, timer_data.time)

    {:noreply, socket}
  end

  @doc """
  Callback function to handle any incoming data from the RobotChannel module
  broadcasted on the "robot:update" topic.
  Assign the values to the variables => "img_robotA", "bottom_robotA", "left_robotA",
  "img_robotB", "bottom_robotB", "left_robotB" and "obstacle_pos" as received.
  Make sure to add a tuple of format: { < obstacle_x >, < obstacle_y > } to the MapSet object "obstacle_pos".
  These values msut be in pixels. You may handle these variables in separate callback functions as well.
  """

  def handle_info(%{"client" => client_robot,"left" => left_value, "bottom" => bottom_value, "face" => face_value} = data, socket) do
    #%{"client" => client_robot,"left" => left_value, "bottom" => bottom_value, "face" => face_value} = data
    if data["client"] == "robot_A" do
      socket = assign(socket, :bottom_robotA, data["bottom"])
      socket = assign(socket, :left_robotA, data["left"])
      case data["face"] do
        "north" -> assign(socket, :img_robotA, "robot_facing_north.png")
        "south" -> assign(socket, :img_robotA, "robot_facing_south.png")
        "east" -> assign(socket, :img_robotA, "robot_facing_east.png")
        "west" -> assign(socket, :img_robotA, "robot_facing_west.png")
      end
    else
      socket = assign(socket, :bottom_robotB, data["bottom"])
      socket = assign(socket, :left_robotB, data["left"])
      case data["face"] do
        "north" -> assign(socket, :img_robotB, "robot_facing_north.png")
        "south" -> assign(socket, :img_robotB, "robot_facing_south.png")
        "east" -> assign(socket, :img_robotB, "robot_facing_east.png")
        "west" -> assign(socket, :img_robotB, "robot_facing_west.png")
      end
    end
    {:noreply, socket}
  end

  def handle_info(%{"obs" => is_obs_ahead, "left" => obs_left_value, "bottom" => obs_bottom_value, "face" => face_value} = data, socket) do
    socket = assign(socket, :obstacle_pos, MapSet.put(socket.assigns.obstacle_pos, {data["left"], data["bottom"]}))
    {:noreply, socket}

  end

  def handle_in("start_posA", message, socket) do
    IO.inspect(message)
    {:noreply, socket}
  end

    # robot, goal_list -> new_list with nearest obstacle first
  def shortest_path(robotA_start, list_plants) do
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
    start_y = Enum.fetch!(start, 1)
    goal_y = Enum.fetch!(goal, 1)
    start_y =
      case start_y do
        "a" -> 1
        "b" -> 2
        "c" -> 3
        "d" -> 4
        "e" -> 5
        "f" -> 6
      end
    goal_y =
      case goal_y do
        "a" -> 1
        "b" -> 2
        "c" -> 3
        "d" -> 4
        "e" -> 5
        "f" -> 6
      end
    diff_x = abs(goal_x - start_x)
    diff_y = abs(goal_y - start_y)
    diff_x + diff_y
  end

  def goal_division(goal_listA, _goal_listB, goal_div_listA, goal_div_listB) when length(goal_listA) <= 1 do
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
  ######################################################
  ## You may create extra helper functions as needed  ##
  ## and update remaining assign variables.           ##
  ######################################################

end
