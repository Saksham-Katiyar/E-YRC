defmodule FW_DEMO do
  @moduledoc """
  Documentation for `FW_DEMO`.

  Different functions provided for testing components of Alpha Bot.
  test_wlf_sensors  - to test white line sensors
  test_ir           - to test IR proximity sensors
  test_motion       - to test motion of the Robot
  test_pwm          - to test speed of the Robot
  test_servo_a      - to test servo motor A
  test_servo_b      - to test servo motor B
  """


  require Logger
  use Bitwise
  alias Circuits.GPIO

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
  @ir2_sensor_value 975
  @ir3_sensor_value 975
  @ir4_sensor_value 975
  @ir5_sensor_value 975

  @forward_pwm 82
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

  def pwm_testing(time,direc,duty1,duty2) do
    Logger.debug("Testing PWM for Motion control")
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    motor_action(motor_ref, direc, 1)

    [line_follow_motion(time,duty1,duty2)]
    #test_motion(40, [@stop])
  end

  defp line_follow_motion(time,value1,value2) do
    IO.puts("Forward with pwm value = #{value1} & #{value2}")
    motion_pwm(value1,value2)
    Process.sleep(time)
  end

  defp motion_pwm(duty1,duty2) do
    Pigpiox.Pwm.gpio_pwm(6, duty1)
    Pigpiox.Pwm.gpio_pwm(26, duty2+11)
  end

  def stop_robot() do
    test_motion(100, [@stop])
  end

  def line_follower() do
    path = ["move","left","move"]
    follow_line(path)
  end

  def follow_line(path) do
    if length(path) > 0 do
      cond do
        Enum.fetch!(path, 0) == "move" ->
          pwm_testing(40,@backward,100,100)
          pwm_testing(40,@backward,100,100)
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

  def go_strt() do

    Logger.debug("go strt")

    ir_values = test_wlf_sensors()
    IO.inspect(ir_values)
    test_965 = Enum.map(ir_values, fn x -> if x > 970 do 1 else 0 end end)
    test_965 = Enum.scan(test_965, &(&1 + &2))
    above_965 = Enum.fetch!(test_965, 3)
    ir2=Enum.fetch!(ir_values,0)
    ir3=Enum.fetch!(ir_values,1)
    ir4=Enum.fetch!(ir_values,2)
    #n = ir_inrange(ir_values)
    diff = ir_diff(ir_values)
    cond do
      above_965 > 2 ->
        test_motion(60, [@backward])
        test_motion(40, [@stop])
        IO.inspect("node_deteted")
        {:ok}
      ir3>=ir2 and ir3>=ir4 ->
        pwm_testing(20,@backward,@forward_pwm,@forward_pwm)
        go_strt()
      ir2>ir4 ->
        pwm_testing(20,@backward,trunc(@forward_pwm), trunc(@forward_pwm + @turning_pwm))
        go_strt()
      ir4>ir2 ->
        pwm_testing(20,@backward,trunc(@forward_pwm + @turning_pwm), trunc(@forward_pwm))
        go_strt()
      true->
        pwm_testing(20, @backward,@forward_pwm,@forward_pwm)
        go_strt()
      # diff < 0 ->
      #   if Enum.fetch!(ir_values,0) < Enum.fetch!(ir_values,3) do
      #     # right
      #     pwm_testing(trunc(@forward_pwm - (diff*@turning_pwm)), trunc(@forward_pwm + (diff*@turning_pwm)))
      #   else
      #     # left
      #     pwm_testing(trunc(@forward_pwm + (diff*@turning_pwm)), trunc(@forward_pwm - (diff*@turning_pwm)))
      #   end
      #   go_strt()
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
    ir_first =  @ir2_sensor_value - Enum.fetch!(ir_values,0)
    ir_second = Enum.fetch!(ir_values,1) - @ir3_sensor_value
    ir_third =  Enum.fetch!(ir_values,2) - @ir4_sensor_value
    ir_fourth = @ir5_sensor_value - Enum.fetch!(ir_values,3)

    diff = ir_first + ir_fourth + 1.5*(ir_second + ir_third)
  end

  def take_turn(turn) do
    Logger.debug("take turn")
    if turn == "right" do
      pwm_testing(300,@right,80,80)
      # test_motion(220, [@right])
      # test_motion(20, [@stop])
      is_turncorrect(@right)
    else
      turn == "left"
      pwm_testing(300,@left,80,80)
      # test_motion(220, [@left])
      # test_motion(20, [@stop])
      is_turncorrect(@left)
    end
  end

  def is_turncorrect(turn) do
    Logger.debug("is_turncorrect")
    detect_white = test_wlf_sensors()
    IO.inspect(detect_white)
    test_800 = Enum.map(detect_white, fn x -> if x > 965 do 1 else 0 end end)
    test_800 = Enum.scan(test_800, &(&1 + &2))
    below_800 = Enum.fetch!(test_800, 3)
    if below_800 >2 do
      pwm_testing(20,turn,60,60)
      # test_motion(40, [turn])
      # test_motion(15, [@stop])
      is_turncorrect(turn)
    else
      pwm_testing(80,turn,60,60)
      pwm_testing(20,turn,0,0)
      {:ok}
    end
  end

  # a - gripper , b - arm
  # give servo some time to rotate
  def sowing() do
    test_servo_a(@angle_front_a)
    Process.sleep(@delay)# add sleep statement here
    test_servo_b(@angle_picking_b)
    Process.sleep(@delay)
    test_servo_a(@angle_back_a)
    Process.sleep(@delay)
    test_servo_b(@angle_placing_b)
    Process.sleep(@delay)
    test_servo_a(@angle_neutral_a)
    Process.sleep(@delay)
  end

  def weeding() do
    test_servo_b(@angle_placing_b)
    Process.sleep(@delay)
    test_servo_a(@angle_back_a)
    Process.sleep(@delay)
    test_servo_b(@angle_picking_b)
    Process.sleep(@delay)
    test_servo_a(@angle_neutral_a)
    Process.sleep(@delay)
    test_motion(60, [@left])
    test_motion(90, [@stop])
    Process.sleep(@delay)
    test_servo_a(@angle_back_a)
    Process.sleep(@delay)
    test_servo_b(@angle_placing_b)
    Process.sleep(@delay)
    test_servo_a(@angle_neutral_a)
    Process.sleep(@delay)
  end
  @doc """
  Tests white line sensor modules reading

  Example:

      iex> FW_DEMO.test_wlf_sensors
      [0, 958, 851, 969, 975, 943]  // on white surface
      [0, 449, 356, 312, 321, 267]  // on black surface
  """
  def test_wlf_sensors do
    #Logger.debug("Testing white line sensors connected ")
    sensor_ref = Enum.map(@sensor_pins, fn {atom, pin_no} -> configure_sensor({atom, pin_no}) end)
    sensor_ref = Enum.map(sensor_ref, fn{_atom, ref_id} -> ref_id end)
    sensor_ref = Enum.zip(@ref_atoms, sensor_ref)
    get_lfa_readings([1,2,3,4,5], sensor_ref)
    # li1=get_lfa_readings([1,2,3,4,5], sensor_ref)
    # li2=get_lfa_readings([1,2,3,4,5], sensor_ref)
    # li3=get_lfa_readings([1,2,3,4,5], sensor_ref)
    # li4=get_lfa_readings([1,2,3,4,5], sensor_ref)
    # li5=get_lfa_readings([1,2,3,4,5], sensor_ref)
    # a=Enum.fetch!(li1,0)+Enum.fetch!(li2,0)+Enum.fetch!(li3,0)+Enum.fetch!(li4,0)+Enum.fetch!(li5,0)
    # b=Enum.fetch!(li1,1)+Enum.fetch!(li2,1)+Enum.fetch!(li3,1)+Enum.fetch!(li4,1)+Enum.fetch!(li5,1)
    # c=Enum.fetch!(li1,2)+Enum.fetch!(li2,2)+Enum.fetch!(li3,2)+Enum.fetch!(li4,2)+Enum.fetch!(li5,2)
    # d=Enum.fetch!(li1,3)+Enum.fetch!(li2,3)+Enum.fetch!(li3,3)+Enum.fetch!(li4,3)+Enum.fetch!(li5,3)
    # li=[a/5,b/5,c/5,d/5]
    # Enum.map(li, fn x -> trunc(x) end)
  end


  @doc """
  Tests IR Proximity sensor's readings

  Example:

      iex> FW_DEMO.test_ir
      [1, 1]     // No obstacle
      [1, 0]     // Obstacle in front of Right IR Sensor
      [0, 1]     // Obstacle in front of Left IR Sensor
      [0, 0]     // Obstacle in front of both Sensors

  Note: You can adjust the potentiometer provided on the IR sensor to get proper results
  """
  def test_ir do
    Logger.debug("Testing IR Proximity Sensors")
    ir_ref = Enum.map(@ir_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :input, pull_mode: :pullup) end)
    ir_values = Enum.map(ir_ref,fn {_, ref_no} -> GPIO.read(ref_no) end)
  end


  @doc """
  Tests motion of the Robot

  Example:

      iex> FW_DEMO.test_motion
      :ok

  Note: On executing above function Robot will move forward, backward, left, right
  for 500ms each and then stops
  """
  def test_motion(sleep, motion_list) do
    IO.inspect("test motion running!!!!")
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    pwm_ref = Enum.map(@pwm_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    Enum.map(pwm_ref,fn {_, ref_no} -> GPIO.write(ref_no, 1) end)
    #Enum.each(@pwm_pins, fn {_atom, pin_no} -> Pigpiox.Pwm.gpio_pwm(pin_no, 100) end)
    Enum.each(motion_list, fn motion -> motor_action(motor_ref,motion, sleep) end)
  end


  @doc """
  Controls speed of the Robot

  Example:

      iex> FW_DEMO.test_pwm
      Forward with pwm value = 150
      Forward with pwm value = 70
      Forward with pwm value = 0
      {:ok, :ok, :ok}

  Note: On executing above function Robot will move in forward direction with different velocities
  """

  def test_pwm do
    Logger.debug("Testing PWM for Motion control")
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    motor_action(motor_ref, @backward, 200)
    Enum.map(@duty_cycles, fn value -> motion_pwm(value) end)
  end


  @doc """
  Controls angle of serve motor A

  Example:

      iex> FW_DEMO.test_servo_a(90)
      :ok

  Note: On executing above function servo motor A will rotate by 90 degrees. You can provide
  values from 0 to 180
  """
  def test_servo_a(angle) do
    Logger.debug("Testing Servo A")
    val = trunc(((2.5 + 10.0 * angle / 180) / 100 ) * 255)
    Pigpiox.Pwm.set_pwm_frequency(@servo_a_pin, @pwm_frequency)
    Pigpiox.Pwm.gpio_pwm(@servo_a_pin, val)
  end


  @doc """
  Controls angle of serve motor B

  Example:

      iex> FW_DEMO.test_servo_b(90)
      :ok

  Note: On executing above function servo motor B will rotate by 90 degrees. You can provide
  values from 0 to 180
  """
  def test_servo_b(angle) do
    Logger.debug("Testing Servo B")
    val = trunc(((2.5 + 10.0 * angle / 180) / 100 ) * 255)
    Pigpiox.Pwm.set_pwm_frequency(@servo_b_pin, @pwm_frequency)
    Pigpiox.Pwm.gpio_pwm(@servo_b_pin, val)
  end

  @doc """
  Supporting function for test_wlf_sensors
  Configures sensor pins as input or output

  [cs: output, clock: output, address: output, dataout: input]
  """
  defp configure_sensor({atom, pin_no}) do
    if (atom == :dataout) do
      GPIO.open(pin_no, :input, pull_mode: :pullup)
    else
      GPIO.open(pin_no, :output)
    end
  end

  @doc """
  Supporting function for test_wlf_sensors
  Reads the sensor values into an array. "sensor_list" is used to provide list
  of the sesnors for which readings are needed


  The values returned are a measure of the reflectance in abstract units,
  with higher values corresponding to lower reflectance (e.g. a black
  surface or void)
  """
  # defp get_lfa_readings(sensor_list, sensor_ref) do
  #   append_sensor_list = sensor_list ++ [5]
  #   temp_sensor_list = [5 | append_sensor_list]
  #   IO.inspect(append_sensor_list
  #       |> Enum.with_index
  #       |> Enum.map(fn {sens_num, sens_idx} ->
  #             analog_read(sens_num, sensor_ref, Enum.fetch(temp_sensor_list, sens_idx))
  #             end))
  #   Enum.each(0..5, fn n -> provide_clock(sensor_ref) end)
  #   GPIO.write(sensor_ref[:cs], 1)
  #   Process.sleep(250)
  #   # get_lfa_readings(sensor_list, sensor_ref)
  # end
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

  @doc """
  Supporting function for test_wlf_sensors
  """
  defp analog_read(sens_num, sensor_ref, {_, sensor_atom_num}) do

    GPIO.write(sensor_ref[:cs], 0)
    %{^sensor_atom_num => sensor_atom} = @lf_sensor_map
    Enum.reduce(0..9, @lf_sensor_data, fn n, acc ->
                                          read_data(n, acc, sens_num, sensor_ref, sensor_atom_num)
                                          |> clock_signal(n, sensor_ref)
                                        end)[sensor_atom]
  end

  @doc """
  Supporting function for test_wlf_sensors
  """
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

  @doc """
  Supporting function for test_wlf_sensors used for providing clock pulses
  """
  defp provide_clock(sensor_ref) do
    GPIO.write(sensor_ref[:clock], 1)
    GPIO.write(sensor_ref[:clock], 0)
  end

  @doc """
  Supporting function for test_wlf_sensors used for providing clock pulses
  """
  defp clock_signal(acc, n, sensor_ref) do
    GPIO.write(sensor_ref[:clock], 1)
    GPIO.write(sensor_ref[:clock], 0)
    acc
  end

  @doc """
  Supporting function for test_motion
  """
  defp motor_action(motor_ref,motion, sleep) do
    motor_ref |> Enum.zip(motion) |> Enum.each(fn {{_, ref_no}, value} -> GPIO.write(ref_no, value) end)
    Process.sleep(sleep)
  end

  @doc """
  Supporting function for test_pwm
  """
  defp motion_pwm(value) do
    IO.puts("Forward with pwm value = #{value}")
    pwm(value)
    Process.sleep(2000)
  end

  @doc """
  Supporting function for test_pwm
  pwm_ref = Enum.map(@pwm_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
  Enum.map(pwm_ref,fn {_, ref_no} -> GPIO.write(ref_no, 1) end)
  Note: "duty" variable can take value from 0 to 255. Value 255 indicates 100% duty cycle
  """
  defp pwm(duty) do
    Enum.each(@pwm_pins, fn {_atom, pin_no} -> Pigpiox.Pwm.gpio_pwm(pin_no, duty) end)
  end

end

