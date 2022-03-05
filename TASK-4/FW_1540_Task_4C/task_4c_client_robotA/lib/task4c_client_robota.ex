defmodule Task4CClientRobotA do

  require Logger
  use Bitwise
  alias Circuits.GPIO
  # max x-coordinate of table top
  @table_top_x 6
  # max y-coordinate of table top
  @table_top_y :f
  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5, :f => 6}

  @bool_to_int %{:true => 1, :false => 0}

  @sensor_pins [cs: 5, clock: 25, address: 24, dataout: 23]
  @ir_pins [dr: 16, dl: 19]
  @motor_pins [lf: 12, lb: 13, rf: 20, rb: 21]
  @pwm_pins [enl: 6, enr: 26]
  @servo_a_pin 27
  @servo_b_pin 22

  @ref_atoms [:cs, :clock, :address, :dataout]
  @lf_sensor_data %{sensor0: 0, sensor1: 0, sensor2: 0, sensor3: 0, sensor4: 0, sensor5: 0}
  @lf_sensor_map %{0 => :sensor0, 1 => :sensor1, 2 => :sensor2, 3 => :sensor3, 4 => :sensor4, 5 => :sensor5}

  @forward [0, 1, 1, 0]
  @backward [1, 0, 0, 1]
  @left [0, 1, 0, 1]
  @right [1, 0, 1, 0]
  @stop [0, 0, 0, 0]

  @inside_sensor_range 965..999
  @outside_sensor_range 650..964
  @ir2_sensor_value 943
  @ir3_sensor_value 963
  @ir4_sensor_value 973
  @ir5_sensor_value 870

  @forward_pwm 100
  @conv_diff_to_pwm 0.02
  @turning_pwm 12

  @duty_cycles [150, 70, 0]
  @pwm_frequency 50

  @angle_front_a 30
  @angle_back_a 160
  @angle_neutral_a 90
  @angle_picking_b 27
  @angle_placing_b 80
  @delay 1000

  @doc """
  Places the robot to the default position of (1, A, North)

  Examples:

      iex> Task4CClientRobotA.place
      {:ok, %Task4CClientRobotA.Position{facing: :north, x: 1, y: :a}}
  """
  def place do
    {:ok, %Task4CClientRobotA.Position{}}
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

      iex> Task4CClientRobotA.place(1, :b, :south)
      {:ok, %Task4CClientRobotA.Position{facing: :south, x: 1, y: :b}}

      iex> Task4CClientRobotA.place(-1, :f, :north)
      {:failure, "Invalid position"}

      iex> Task4CClientRobotA.place(3, :c, :north_east)
      {:failure, "Invalid facing direction"}
  """
  def place(x, y, facing) do
    {:ok, %Task4CClientRobotA.Position{x: x, y: y, facing: facing}}
  end

  @doc """
  Provide START position to the robot as given location of (x, y, facing) and place it.
  """
  def start(x, y, facing) do
    place(x, y, facing)
  end

  @doc """
  Main function to initiate the sequence of tasks to achieve by the Client Robot A,
  such as connect to the Phoenix server, get the robot A's start and goal locations to be traversed.
  Call the respective functions from this module and others as needed.
  You may create extra helper functions as needed.
  """

  def main do
    {:ok, _response, channel} = Task4CClientRobotA.PhoenixSocketClient.connect_server()
    message =  Task4CClientRobotA.PhoenixSocketClient.receive_pos(channel)
    start_robot(message, channel)
  end

  def start_robot(message, channel) do
    IO.inspect("robotA  started moving")
    robotA_start = message["robotA_start"]
    goal_div_listA = message["goal_div_listA"]

    # :ets.new(:robotA, [:named_table])
    # :ets.insert(:robotA, {:robotA, {"killed", true}})

    x_loc = String.to_integer(Enum.fetch!(robotA_start, 0))
    y_loc = String.to_atom(Enum.fetch!(robotA_start, 1))
    facing = String.to_atom(Enum.fetch!(robotA_start, 2))
    robot = %Task4CClientRobotA.Position{x: x_loc, y: y_loc, facing: facing}
    goal_locs = goal_div_listA
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

  def move_goal(goal_div_listA, robot, channel, i) when length(goal_div_listA) == i do
    #_is_obstacle = Task4CClientRobotA.PhoenixSocketClient.send_robot_status(channel, robot, 1)
    {:ok, robot}
  end

  def move_goal(goal_div_listA, robot, channel, i) when length(goal_div_listA) > i do
    goal = Enum.fetch!(goal_div_listA, i)
    goal_x = String.to_integer(Enum.fetch!(goal, 0))
    goal_y = String.to_atom(Enum.fetch!(goal, 1))
    goal_y_number = Map.get(@robot_map_y_atom_to_num, goal_y)
    IO.inspect(robot)
    IO.inspect(goal_x)
    IO.inspect(goal_y)
    IO.inspect(channel)
    robot = traverse(robot, goal_x, goal_y, channel)
    if Enum.fetch!(goal, 2) == "sowing" do
      move_goal(goal_div_listA, robot, channel, i+1)
    else
      robot = deposit(robot, channel)
      move_goal(goal_div_listA, robot, channel, i+1)
    end
    #move_goal(goal_div_listA, robot, channel, i+1)
  end

  def deposit(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot, channel) do
    dist_x = 6 - x
    dist_y = 6 - Map.get(@robot_map_y_atom_to_num, y)
    robot = cond do
              dist_x < dist_y ->
                robot = depo_traverse(robot, 6, y, channel)
                case robot.facing do
                  :north -> right(robot)
                  :south -> left(robot)
                  _ -> robot
                end
              true ->
                robot = depo_traverse(robot, x, :f, channel)
                case robot.facing do
                  :east -> left(robot)
                  :west -> right(robot)
                  _ -> robot
                end
            end
    robot
  end

  defp depo_traverse(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot, goal_x, goal_y, channel) when x == 6 or y == :f do
    _is_obstacle = Task4CClientRobotA.PhoenixSocketClient.send_robot_status(channel, robot, 0)
    robot
  end

  defp depo_traverse(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot, goal_x, goal_y, channel) do

    killed = Task4CClientRobotA.PhoenixSocketClient.receive_killed(channel)
    if killed do
      Process.sleep(1000)
    else
      Process.sleep(100)
      is_obstacle = Task4CClientRobotA.PhoenixSocketClient.send_robot_status(channel, robot, 0)
      robot = if is_obstacle do
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
    end
    depo_traverse(robot, goal_x, goal_y, channel)
  end

  ###################### deposition is wrong , obstacle avoidance not taken into account ####################

  # def deposition_y(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot) do
  #   case facing do
  #     :east ->
  #       left(robot)
  #     :west ->
  #       right(robot)
  #     :south ->
  #       robot = left(robot)
  #       left(robot)
  #   end
  #   diff_y = abs(6 - Map.get(@robot_map_y_atom_to_num, y))
  #   go_strt(robot, diff_y)
  # end

  # def deposition_x(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot) do
  #   case facing do
  #     :north ->
  #       right(robot)
  #     :west ->
  #       robot = right(robot)
  #       right(robot)
  #     :south ->
  #       left(robot)
  #   end
  #   diff_x = abs(6 - x)
  #   go_strt(robot, diff_x)
  # end

  # def go_strt(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot, 0) do
  #   robot
  # end

  # def go_strt(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot, diff) do
  #   move_check(robot)
  #   go_strt(robot, diff - 1)
  # end

  defp traverse(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot, goal_x, goal_y, channel) when x == goal_x and y == goal_y do
    _is_obstacle = Task4CClientRobotA.PhoenixSocketClient.send_robot_status(channel, robot, 0)
    ############### do sowing and weeding #######################
    robot
  end

  defp traverse(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot, goal_x, goal_y, channel) do

    killed = Task4CClientRobotA.PhoenixSocketClient.receive_killed(channel)
    if killed do
      Process.sleep(1000)
    else
      Process.sleep(100)
      IO.inspect("traverse to goal")
      is_obstacle_0 = Task4CClientRobotA.PhoenixSocketClient.send_robot_status(channel, robot, 0)

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
    end
    traverse(robot, goal_x, goal_y, channel)
  end

  defp move_possible(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = _robot) do
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
    if Task4CClientRobotA.PhoenixSocketClient.send_robot_status(channel, robot, 0) or !move_possible(robot) do
      left_until_free(robot, channel)
    else
      robot
    end
  end

  defp obstacle_sequence(robot, channel) do
    robot = left_until_free(robot, channel)
    robot = move_check(robot)
    _ = Task4CClientRobotA.PhoenixSocketClient.send_robot_status(channel, robot, 0)
    robot = right(robot)
    if !Task4CClientRobotA.PhoenixSocketClient.send_robot_status(channel, robot, 0) and move_possible(robot) do
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

  # def deposit(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot, channel) do
  #   dist_x = 6 - x
  #   dist_y = 6 - Map.get(@robot_map_y_atom_to_num, y)
  #   robot = cond do
  #     dist_x < dist_y ->
  #       robot = depo_traverse(robot, 6, y, channel)
  #       case robot.facing do
  #         :north -> right(robot)
  #         :south -> left(robot)
  #         _ -> robot
  #       end
  #     true ->
  #       robot = depo_traverse(robot, x, :f, channel)
  #       case robot.facing do
  #         :east -> left(robot)
  #         :west -> right(robot)
  #         _ -> robot
  #       end
  #   end
  #   robot
  # end

  # defp depo_traverse(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot, goal_x, goal_y, channel) when x == 6 or y == :f do
  #   _is_obstacle = Task4CClientRobotA.PhoenixSocketClient.send_robot_status(channel, robot, 0)
  #   robot
  # end

  # defp depo_traverse(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot, goal_x, goal_y, channel) do
  #   is_obstacle = Task4CClientRobotA.PhoenixSocketClient.send_robot_status(channel, robot, 0)

  #   robot = if is_obstacle do
  #             obstacle_sequence(robot, channel)
  #           else
  #             x_direction = if goal_x > x do :east else :west end
  #             y_direction = if goal_y > y do :north else :south end
  #             cond do
  #               x != goal_x and facing != x_direction -> right(robot)
  #               x != goal_x and facing == x_direction -> move_check(robot)
  #               y != goal_y and facing != y_direction -> left(robot)
  #               y != goal_y and facing == y_direction -> move_check(robot)
  #               true -> IO.puts("No matching clause: x:#{x} y:#{y} F:#{facing} X-dir:#{x_direction} Y-dir:#{y_direction} Goal_X:#{goal_x} Goal_Y:#{goal_y}")
  #             end
  #           end
  #   depo_traverse(robot, goal_x, goal_y, channel)
  # end

  @doc """
  Provides the report of the robot's current position

  Examples:

      iex> {:ok, robot} = Task4CClientRobotA.place(2, :b, :west)
      iex> Task4CClientRobotA.report(robot)
      {2, :b, :west}
  """
  def report(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = _robot) do
    {x, y, facing}
  end

  @directions_to_the_right %{north: :east, east: :south, south: :west, west: :north}
  @doc """
  Rotates the robot to the right
  """
  def right(%Task4CClientRobotA.Position{facing: facing} = robot) do
    path = ["right"]
    line_follower(path)
    %Task4CClientRobotA.Position{robot | facing: @directions_to_the_right[facing]}
  end

  @directions_to_the_left Enum.map(@directions_to_the_right, fn {from, to} -> {to, from} end)
  @doc """
  Rotates the robot to the left
  """
  def left(%Task4CClientRobotA.Position{facing: facing} = robot) do
    path = ["left"]
    line_follower(path)
    %Task4CClientRobotA.Position{robot | facing: @directions_to_the_left[facing]}
  end

  @doc """
  Moves the robot to the north, but prevents it to fall
  """
  def move(%Task4CClientRobotA.Position{x: _, y: y, facing: :north} = robot) when y < @table_top_y do
    path = ["move"]
    line_follower(path)
    %Task4CClientRobotA.Position{ robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) + 1 end) |> elem(0)}

  end

  @doc """
  Moves the robot to the east, but prevents it to fall
  """
  def move(%Task4CClientRobotA.Position{x: x, y: _, facing: :east} = robot) when x < @table_top_x do
    path = ["move"]
    line_follower(path)
    %Task4CClientRobotA.Position{robot | x: x + 1}
  end

  @doc """
  Moves the robot to the south, but prevents it to fall
  """
  def move(%Task4CClientRobotA.Position{x: _, y: y, facing: :south} = robot) when y > :a do
    path = ["move"]
    line_follower(path)
    %Task4CClientRobotA.Position{ robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) - 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the west, but prevents it to fall
  """
  def move(%Task4CClientRobotA.Position{x: x, y: _, facing: :west} = robot) when x > 1 do
    path = ["move"]
    line_follower(path)
    %Task4CClientRobotA.Position{robot | x: x - 1}
  end

  @doc """
  Does not change the position of the robot.
  This function used as fallback if the robot cannot move outside the table
  """
  def line_follower(path) do
    follow_line(path)
  end

  def follow_line(path) do
    if length(path) > 0 do
      cond do
        Enum.fetch!(path, 0) == "move" ->
          pwm_testing(@forward_pwm,@forward_pwm)
          pwm_testing(@forward_pwm,@forward_pwm)
          go_strt()
        Enum.fetch!(path, 0) == "right" -> take_turn("right")
        Enum.fetch!(path, 0) == "left" -> take_turn("left")
      end
      IO.inspect(path)
      path = List.delete_at(path, 0)
      follow_line(path)
    else
      test_motion(100, [@stop])
      {:ok, path}
    end
  end

  def pwm_testing(duty1,duty2) do
    Logger.debug("Testing PWM for Motion control")
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    motor_action(motor_ref, @forward, 1)
    [line_follow_motion(duty1,duty2)]
    #test_motion(40, [@stop])
  end

  defp line_follow_motion(value1,value2) do
    IO.puts("Forward with pwm value = #{value1} & #{value2}")
    motion_pwm(value1,value2)
    Process.sleep(40)
  end

  defp motion_pwm(duty1,duty2) do
    Pigpiox.Pwm.gpio_pwm(6, duty1)
    Pigpiox.Pwm.gpio_pwm(26, duty2)
  end

  def go_strt() do
    Logger.debug("go strt")
    ir_values = test_wlf_sensors()
    IO.inspect(ir_values)
    test_965 = Enum.map(ir_values, fn x -> if x > 970 do 1 else 0 end end)
    test_965 = Enum.scan(test_965, &(&1 + &2))
    above_965 = Enum.fetch!(test_965, 3)
    n = ir_inrange(ir_values)
    diff = ir_diff(ir_values)
    cond do
      above_965 > 2 ->
        test_motion(60, [@forward])
        test_motion(40, [@stop])
        IO.inspect("node_deteted")
        {:ok}
      n > 3 ->
        pwm_testing(@forward_pwm,@forward_pwm)
        go_strt()
      n <= 3 ->
        # turning_pwm = diff*@conv_diff_to_pwm
        a= if diff > 0 do
          1
        else
          -1
        end
        pwm_testing(trunc(@forward_pwm + (a*@turning_pwm)), trunc(@forward_pwm - (a*@turning_pwm)))
        # Pigpiox.Pwm.gpio_pwm(6, @forward_pwm - turning_pwm) #left motor
        # Pigpiox.Pwm.gpio_pwm(26, @forward_pwm + turning_pwm) #right_motor
        # Process.sleep(500)
        go_strt()
    end
  end

  def ir_inrange(ir_values) do
    ir_first = Enum.fetch!(ir_values,0) in @outside_sensor_range
    ir_second = Enum.fetch!(ir_values,1) in @inside_sensor_range
    ir_third = Enum.fetch!(ir_values,2) in @inside_sensor_range
    ir_fourth = Enum.fetch!(ir_values,3) in @outside_sensor_range
    n = @bool_to_int[ir_first] + @bool_to_int[ir_second] + @bool_to_int[ir_third] + @bool_to_int[ir_fourth]
    IO.inspect(Enum.fetch!(ir_values,0))
    IO.inspect([n,ir_first,ir_second,ir_third,ir_fourth])
    n
  end

  def ir_diff(ir_values) do
    ir_first = Enum.fetch!(ir_values,0) - @ir2_sensor_value
    ir_second = Enum.fetch!(ir_values,1) - @ir3_sensor_value
    ir_third = @ir4_sensor_value - Enum.fetch!(ir_values,2)
    ir_fourth = @ir5_sensor_value - Enum.fetch!(ir_values,3)

    diff = ir_first + ir_fourth + 1.5*(ir_second + ir_third)
  end

  def take_turn(turn) do
    Logger.debug("take turn")
    if turn == "right" do
      test_motion(220, [@right])
      test_motion(20, [@stop])
      is_turncorrect(@right)
    else
      turn == "left"
      test_motion(220, [@left])
      test_motion(20, [@stop])
      is_turncorrect(@left)
    end
  end

  def is_turncorrect(turn) do
    Logger.debug("is_turncorrect")
    detect_white = test_wlf_sensors()
    test_800 = Enum.map(detect_white, fn x -> if x < 800 do 1 else 0 end end)
    test_800 = Enum.scan(test_800, &(&1 + &2))
    below_800 = Enum.fetch!(test_800, 3)
    if below_800 == 4 do
      test_motion(40, [turn])
      test_motion(15, [@stop])
      is_turncorrect(turn)
    else
      {:ok}
    end
  end

  def test_wlf_sensors do
    #Logger.debug("Testing white line sensors connected ")
    sensor_ref = Enum.map(@sensor_pins, fn {atom, pin_no} -> configure_sensor({atom, pin_no}) end)
    sensor_ref = Enum.map(sensor_ref, fn{_atom, ref_id} -> ref_id end)
    sensor_ref = Enum.zip(@ref_atoms, sensor_ref)
    get_lfa_readings([1,2,3,4,5], sensor_ref)
  end

  def test_ir do
    Logger.debug("Testing IR Proximity Sensors")
    ir_ref = Enum.map(@ir_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :input, pull_mode: :pullup) end)
    ir_values = Enum.map(ir_ref,fn {_, ref_no} -> GPIO.read(ref_no) end)
  end

  def test_motion(sleep, motion_list) do
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    pwm_ref = Enum.map(@pwm_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    Enum.map(pwm_ref,fn {_, ref_no} -> GPIO.write(ref_no, 1) end)
    #Enum.each(@pwm_pins, fn {_atom, pin_no} -> Pigpiox.Pwm.gpio_pwm(pin_no, 100) end)
    Enum.each(motion_list, fn motion -> motor_action(motor_ref,motion, sleep) end)
  end

  def test_pwm do
    Logger.debug("Testing PWM for Motion control")
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    motor_action(motor_ref, @backward, 200)
    Enum.map(@duty_cycles, fn value -> motion_pwm(value) end)
  end

  def test_servo_a(angle) do
    Logger.debug("Testing Servo A")
    val = trunc(((2.5 + 10.0 * angle / 180) / 100 ) * 255)
    Pigpiox.Pwm.set_pwm_frequency(@servo_a_pin, @pwm_frequency)
    Pigpiox.Pwm.gpio_pwm(@servo_a_pin, val)
  end

  def test_servo_b(angle) do
    Logger.debug("Testing Servo B")
    val = trunc(((2.5 + 10.0 * angle / 180) / 100 ) * 255)
    Pigpiox.Pwm.set_pwm_frequency(@servo_b_pin, @pwm_frequency)
    Pigpiox.Pwm.gpio_pwm(@servo_b_pin, val)
  end

  defp configure_sensor({atom, pin_no}) do
    if (atom == :dataout) do
      GPIO.open(pin_no, :input, pull_mode: :pullup)
    else
      GPIO.open(pin_no, :output)
    end
  end

  defp get_lfa_readings(sensor_list, sensor_ref) do
    append_sensor_list = sensor_list ++ [5]
    temp_sensor_list = [5 | append_sensor_list]
    detect_white = append_sensor_list
        |> Enum.with_index
        |> Enum.map(fn {sens_num, sens_idx} ->
              analog_read(sens_num, sensor_ref, Enum.fetch(temp_sensor_list, sens_idx))
              end)
    Enum.each(0..5, fn n -> provide_clock(sensor_ref) end)
    GPIO.write(sensor_ref[:cs], 1)
    #Process.sleep(250)
    #get_lfa_readings(sensor_list, sensor_ref)
    detect_white = List.delete_at(detect_white, 5)
    detect_white = List.delete_at(detect_white, 0)
    #IO.inspect(detect_white)
    detect_white
  end

  defp analog_read(sens_num, sensor_ref, {_, sensor_atom_num}) do

    GPIO.write(sensor_ref[:cs], 0)
    %{^sensor_atom_num => sensor_atom} = @lf_sensor_map
    Enum.reduce(0..9, @lf_sensor_data, fn n, acc ->
                                          read_data(n, acc, sens_num, sensor_ref, sensor_atom_num)
                                          |> clock_signal(n, sensor_ref)
                                        end)[sensor_atom]
  end

  defp read_data(n, acc, sens_num, sensor_ref, sensor_atom_num) do
    if (n < 4) do

      if (((sens_num) >>> (3 - n)) &&& 0x01) == 1 do
        GPIO.write(sensor_ref[:address], 1)
      else
        GPIO.write(sensor_ref[:address], 0)
      end
      Process.sleep(1)
    end

    %{^sensor_atom_num => sensor_atom} = @lf_sensor_map
    if (n <= 9) do
      Map.update!(acc, sensor_atom, fn sensor_atom -> ( sensor_atom <<< 1 ||| GPIO.read(sensor_ref[:dataout]) ) end)
    end
  end

  defp provide_clock(sensor_ref) do
    GPIO.write(sensor_ref[:clock], 1)
    GPIO.write(sensor_ref[:clock], 0)
  end

  defp clock_signal(acc, n, sensor_ref) do
    GPIO.write(sensor_ref[:clock], 1)
    GPIO.write(sensor_ref[:clock], 0)
    acc
  end

  defp motor_action(motor_ref,motion, sleep) do
    motor_ref |> Enum.zip(motion) |> Enum.each(fn {{_, ref_no}, value} -> GPIO.write(ref_no, value) end)
    Process.sleep(sleep)
  end

  defp motion_pwm(value) do
    IO.puts("Forward with pwm value = #{value}")
    pwm(value)
    Process.sleep(2000)
  end

  defp interrupt()

  defp pwm(duty) do
    Enum.each(@pwm_pins, fn {_atom, pin_no} -> Pigpiox.Pwm.gpio_pwm(pin_no, duty) end)
  end

  def move(robot), do: robot

  def failure do
    raise "Connection has been lost"
  end
end
