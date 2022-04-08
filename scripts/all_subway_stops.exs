defmodule AllSubwayStops do
  @moduledoc """
  Synthesizes a sample announcement for every subway stop.
  """

  alias PollyScripts.Polly

  def synthesize_all_to_files(all_subway_station_names, output_dir) do
    prepare_dir(output_dir)

    failed =
      all_subway_station_names
      |> Enum.map(&make_sample_sentence/1)
      |> Task.async_stream(&synthesize_to_file(&1, output_dir), timeout: :infinity)
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.zip(all_subway_station_names)
      |> Enum.flat_map(fn
        {:ok, _} -> []
        {error, name} when is_binary(name) -> [{name, error}]
        {error, {name, _}} -> [{name, error}]
      end)

    case failed do
      [] ->
        IO.puts("TTS synthesis succeeded.")

      failed ->
        IO.puts("#{length(failed)} samples failed to synthesize to file.")
        Enum.each(failed, fn {name, error} -> IO.inspect(error, label: name) end)
    end
  end

  defp make_sample_sentence(station), do: "The train to #{station} is now arriving."

  defp prepare_dir(dir_path) do
    File.rm_rf!(dir_path)
    File.mkdir_p!(dir_path)
  end

  defp synthesize_to_file(text, output_dir) when is_binary(text) do
    case Polly.synthesize(text) do
      {:ok, audio_data} ->
        text
        |> get_file_path(output_dir)
        |> File.write(audio_data)

      error ->
        error
    end
  end

  defp get_file_path(text, output_dir) do
    Path.join(output_dir, sanitize_filename(text) <> ".mp3")
  end

  defp sanitize_filename(string) do
    string
    |> String.replace(~r|[/\s]|, "-")
    |> String.replace(~r|[\.'ʼ,:]|, "")
  end
end

# curl -X GET "https://api-v3.mbta.com/stops?include=route&filter%5Broute%5D=Red%2COrange%2CBlue%2CGreen-B%2CGreen-C%2CGreen-D%2CGreen-E%2CMattapan&filter%5Blocation_type%5D=1" -H  "accept: application/vnd.api+json" | jq '.data | map(.attributes.name) | unique'
all_subway_station_names = [
  "Airport",
  "Alewife",
  "Allston Street",
  "Amory Street",
  "Andrew",
  "Aquarium",
  "Arlington",
  "Ashmont",
  "Assembly",
  "Babcock Street",
  "Back Bay",
  "Back of the Hill",
  "Beachmont",
  "Beaconsfield",
  "Blandford Street",
  "Boston College",
  "Boston University Central",
  "Boston University East",
  "Bowdoin",
  "Boylston",
  "Braintree",
  "Brandon Hall",
  "Brigham Circle",
  "Broadway",
  "Brookline Hills",
  "Brookline Village",
  "Butler",
  "Capen Street",
  "Cedar Grove",
  "Central",
  "Central Avenue",
  "Charles/MGH",
  "Chestnut Hill",
  "Chestnut Hill Avenue",
  "Chinatown",
  "Chiswick Road",
  "Cleveland Circle",
  "Community College",
  "Coolidge Corner",
  "Copley",
  "Davis",
  "Dean Road",
  "Downtown Crossing",
  "Eliot",
  "Englewood Avenue",
  "Fairbanks Street",
  "Fenway",
  "Fenwood Road",
  "Fields Corner",
  "Forest Hills",
  "Government Center",
  "Green Street",
  "Griggs Street",
  "Harvard",
  "Harvard Avenue",
  "Hawes Street",
  "Haymarket",
  "Heath Street",
  "Hynes Convention Center",
  "JFK/UMass",
  "Jackson Square",
  "Kendall/MIT",
  "Kenmore",
  "Kent Street",
  "Lechmere",
  "Longwood",
  "Longwood Medical Area",
  "Malden Center",
  "Massachusetts Avenue",
  "Mattapan",
  "Maverick",
  "Milton",
  "Mission Park",
  "Museum of Fine Arts",
  "Newton Centre",
  "Newton Highlands",
  "North Quincy",
  "North Station",
  "Northeastern University",
  "Oak Grove",
  "Orient Heights",
  "Packard's Corner",
  "Park Street",
  "Porter",
  "Prudential",
  "Quincy Adams",
  "Quincy Center",
  "Reservoir",
  "Revere Beach",
  "Riverside",
  "Riverway",
  "Roxbury Crossing",
  "Ruggles",
  "Saint Mary's Street",
  "Saint Paul Street",
  "Savin Hill",
  "Science Park/West End",
  "Shawmut",
  "South Station",
  "South Street",
  "State",
  "Stony Brook",
  "Suffolk Downs",
  "Sullivan Square",
  "Summit Avenue",
  "Sutherland Road",
  "Symphony",
  "Tappan Street",
  "Tufts Medical Center",
  "Union Square",
  "Valley Road",
  "Waban",
  "Warren Street",
  "Washington Square",
  "Washington Street",
  "Wellington",
  "Wollaston",
  "Wonderland",
  "Wood Island",
  "Woodland"
]

output_dir = Path.join([File.cwd!(), "output", "subway_stop_names"])

AllSubwayStops.synthesize_all_to_files(all_subway_station_names, output_dir)
