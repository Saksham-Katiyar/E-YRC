defp read_plant_positions do
  plants_data = File.read!("Plant_Positions.csv")

  list_plants = plants_data |> String.trim |> String.split("\n")
  list_plants = Enum.map(list_plants, fn params -> String.split(params, ",") end)
  list_plants = list_plants -- [["Sowing", "Weeding"]]

  list_sowing = Enum.map(list_plants, fn params -> String.to_integer(hd(params)) end)
  list_weeding = Enum.map(list_plants, fn params -> String.to_integer(hd(tl(params))) end)
  # list_plants = plants_data |> String.trim |> String.replace(" | ", "\n") |> String.split("\n")
  # list_plants = Enum.map(list_plants, fn params -> String.split(params, " ") |> process_plants_params end)
  # IO.inspect(list_plants)
end
