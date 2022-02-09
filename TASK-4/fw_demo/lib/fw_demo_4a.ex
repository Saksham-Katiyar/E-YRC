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

  @duty_cycles [150, 70, 0]
  @pwm_frequency 50

  @angle_picking 30
  @angle_placing -30
  @angle_sowing 150
  @angle_weeding -60

  def line_follower() do
    path = ["move", "right", "move", "move"]
    follow_line(path)
  end

  def follow_line(path) do
    if length(path) > 0 do
      cond do
        Enum.fetch!(path, 0) == "move" -> go_strt()
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
    detect_white = test_wlf_sensors()
    IO.inspect(detect_white)
    test_950 = Enum.map(detect_white, fn x -> if x > 950 do 1 else 0 end end)
    test_950 = Enum.scan(test_950, &(&1 + &2))
    above_950 = Enum.fetch!(test_950, 4)
    test_800 = Enum.map(detect_white, fn x -> if x < 800 do 1 else 0 end end)
    test_800 = Enum.scan(test_800, &(&1 + &2))
    below_800 = Enum.fetch!(test_800, 4)
    max_detect = Enum.max(detect_white)
    avg_detect = (-1 * Enum.fetch!(detect_white, 0)) + (-1 * Enum.fetch!(detect_white, 1)) + Enum.fetch!(detect_white, 3) + Enum.fetch!(detect_white, 4)
    cond do
      above_950 > 3 ->
        test_motion(60, [@forward])
        test_motion(40, [@stop])
        {:ok}
      Enum.fetch!(detect_white, 0) > 950 ->
        test_motion(30, [@left])
        test_motion(10, [@stop])
        go_strt()
      Enum.fetch!(detect_white, 4) > 950 ->
        test_motion(30, [@right])
        test_motion(10, [@stop])
        go_strt()
      true ->
        test_motion(60, [@forward])
        test_motion(10, [@stop])
        go_strt()
    end
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
    below_800 = Enum.fetch!(test_800, 4)
    if below_800 == 5 do
      test_motion(40, [turn])
      test_motion(15, [@stop])
      is_turncorrect(turn)
    else
      {:ok}
    end
  end

  # a - gripper , b - arm
  def sowing() do
    test_servo_a(@angle_picking)
    test_servo_b(@angle_sowing)
    test_servo_a(@angle_placing)
    test_servo_b(-30)
  end

  def weeding() do
    test_servo_b(30)
    test_servo_a(@angle_picking)
    test_servo_b(@angle_weeding)
    test_motion(90, [@left])
    test_servo_b(-@@angle_weeding)
    test_servo_a(@angle_placing)
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
    motor_action(motor_ref, @forward, 200)
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
    Process.sleep(250)
    #get_lfa_readings(sensor_list, sensor_ref)
    detect_white = List.delete_at(detect_white, 5)
    List.replace_at(detect_white, 0, Enum.fetch!(detect_white, 1))
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
