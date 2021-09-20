defmodule GlType9Announcements do
  @moduledoc """
  Synthesizes all announcements, and converts them from original mp3 to
  mp3 at the sample rate/other properties required by the type 9 cars.
  """

  alias PollyScripts.Polly

  def synthesize_all_to_files(announcements, output_dir) do
    mp3_dir = Path.join(output_dir, "original_mp3")
    compliant_mp3_dir = Path.join(output_dir, "compliant_mp3")
    prepare_dir(mp3_dir)
    prepare_dir(compliant_mp3_dir)

    failed =
      announcements
      |> Task.async_stream(&synthesize_to_file(&1, mp3_dir), timeout: :infinity)
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.zip(announcements)
      |> Enum.flat_map(fn
        {:ok, _} -> []
        {error, name} when is_binary(name) -> [{name, error}]
        {error, {name, _}} -> [{name, error}]
      end)

    case failed do
      [] ->
        IO.puts("TTS synthesis succeeded.")

      failed ->
        IO.puts("#{length(failed)} announcements failed to synthesize to file.")
        Enum.each(failed, fn {name, error} -> IO.inspect(error, label: name) end)
    end

    compliant_mp3_results =
      convert_all_to_compliant_mp3(mp3_dir, compliant_mp3_dir, ~w[-b:a 64k -ar 32000 -ac 1])

    compliant_mp3_results
    |> Enum.reject(&match?({_, 0}, &1))
    |> Enum.map(&elem(&1, 0))
    |> case do
      [] ->
        IO.puts("compliant mp3 conversion succeeded.")

      failed ->
        IO.puts(
          "#{length(failed)} mp3 files failed to convert to compliant mp3. Failed to produce the following:"
        )

        Enum.each(failed, &IO.inspect/1)
    end
  end

  defp prepare_dir(dir_path) do
    File.rm_rf!(dir_path)
    File.mkdir_p!(dir_path)
  end

  defp synthesize_to_file({text, [ssml: ssml_hint_text]}, output_dir) do
    Polly.synthesize(ssml_hint_text, text_type: :ssml)
    |> case do
      {:ok, audio_data} ->
        text
        |> get_file_path(output_dir)
        |> File.write(audio_data)

      error ->
        error
    end
  end

  defp synthesize_to_file(text, output_dir) when is_binary(text) do
    text
    |> clean_up_text_for_synthesis()
    |> Polly.synthesize()
    |> case do
      {:ok, audio_data} ->
        text
        |> get_file_path(output_dir)
        |> File.write(audio_data)

      error ->
        error
    end
  end

  defp convert_all_to_compliant_mp3(mp3_dir, compliant_mp3_dir, conversion_args) do
    mp3_dir
    |> File.ls!()
    |> Enum.map(&Path.join(mp3_dir, &1))
    |> Enum.map(&mp3_to_compliant_mp3(&1, compliant_mp3_dir, conversion_args))
  end

  defp mp3_to_compliant_mp3(mp3_path, compliant_mp3_dir, conversion_args) do
    compliant_mp3_path =
      mp3_path
      |> Path.basename()
      |> then(fn filename -> Path.join(compliant_mp3_dir, filename) end)

    cmd_args = ["-i", mp3_path] ++ conversion_args ++ [compliant_mp3_path]

    {_, exit_status} = System.cmd("ffmpeg", cmd_args, stderr_to_stdout: true)

    {compliant_mp3_path, exit_status}
  end

  defp get_file_path(announcement, output_dir) do
    Path.join(output_dir, sanitize_filename(announcement) <> ".mp3")
  end

  defp clean_up_text_for_synthesis(text) do
    String.replace(text, ~r|/|, ", ")
  end

  defp sanitize_filename(string) do
    string
    |> String.replace(~r|[/\s]|, "-")
    |> String.replace(~r|[\.'ʼ,:]|, "")
  end
end

prefixes = [
  "This is:",
  "Approaching:",
  "Next stop:",
  "Next and last stop:",
  "The destination of this train is:",
  "This train will run express to:"
]

stops = [
  "Medford/Tufts",
  "Ball Square",
  "Magoun Square",
  "Gilman Square",
  "East Somerville",
  "Union Square",
  "Lechmere",
  "Science Park/West End",
  "North Station",
  "Haymarket",
  "Government Center",
  "Park Street",
  "Boylston",
  "Arlington",
  "Copley",
  "Hynes Convention Center",
  "Kenmore",
  "Blandford Street",
  "Boston University East",
  "Boston University Central",
  "Boston University West",
  "St. Paul Street",
  "Amory Street",
  "Pleasant Street",
  "Babcock Street",
  "Packards Corner",
  "Harvard Avenue",
  "Griggs Street",
  "Allston Street",
  "Warren Street",
  "Washington Street",
  "Sutherland Road",
  "Chiswick Road",
  "Chestnut Hill Avenue",
  "South Street",
  "Boston College",
  "St. Marys Street",
  "Hawes Street",
  "Kent Street",
  "St. Paul Street",
  "Coolidge Corner",
  "Summit Avenue",
  "Brandon Hall",
  "Fairbanks",
  "Washington Square",
  "Tappan Street",
  "Dean Road",
  "Englewood Avenue",
  "Cleveland Circle",
  "Fenway",
  "Longwood",
  "Brookline Village",
  "Brookline Hills",
  "Beaconsfield",
  "Reservoir",
  "Chestnut Hill",
  "Newton Centre",
  "Newton Highlands",
  "Eliot",
  "Waban",
  "Woodland",
  "Riverside",
  "Prudential",
  "Symphony",
  "Northeastern University",
  "Museum of Fine Arts",
  "Longwood Medical Area",
  "Brigham Circle",
  {"Fenwood Road", [ssml: ~S(<speak><prosody rate="slow">Fenwood Road</prosody></speak>)]},
  "Mission Park",
  "Riverway",
  "Back of the Hill",
  "Heath Street/VA Medical Center"
]

prefixed_stops =
  for prefix <- prefixes, stop <- stops do
    case stop do
      {original, [ssml: "<speak>" <> ssml_rest]} ->
        {"#{prefix} #{original}", [ssml: "<speak>#{prefix} #{ssml_rest}"]}

      stop ->
        "#{prefix} #{stop}"
    end
  end

advisories = [
  "This is an express train. This train will not stop.",
  "Doors will open on the left.",
  "Doors will open on the right.",
  "Doors will open on the left or right.",
  "Doors will open on both sides.",
  "This is the last stop.",
  "Thank you for riding the T.",
  "This train is being taken out of service. We apologize for the inconvenience.",
  "This train is out of service. Please do not board this train.",
  "This is a test message.",
  "Please watch your step when exiting the vehicle.",
  "Face coverings are required on MBTA vehicles, and in stations.",
  "Please remember to take your personal belongings before exiting the train.",
  "Please help keep this train clean by disposing your trash in platform waste receptacles.",
  "Please report any suspicious or unattended packages to an MBTA employee.",
  "Customers are required to make priority seating available for seniors and persons with disabilities.",
  "No smoking please.",
  "Change here for bus connections.",
  "Change here for the Red Line, SL5, and bus connections.",
  "Change here for the Orange Line and bus connections.",
  "Change here for the SL5 and bus connections.",
  "Change here for the Blue Line and bus connections.",
  "Change here for the Orange Line, bus connections, Commuter Rail, and Amtrak.",
  "This is the last chance to transfer to Green Line service to Boston College and Cleveland Circle.",
  "This is the last chance to transfer to Green Line service to Cleveland Circle and Riverside.",
  "This is the last chance to transfer to Green Line service to Boston College and Riverside.",
  "This is the last chance to transfer to Green Line service to Boston College, Cleveland Circle, and Riverside.",
  "This is the last chance to transfer to Green Line service to Heath Street.",
  "This is the last chance to transfer to Green Line service to Cleveland Circle and Heath Street.",
  "This is the last chance to transfer to Green Line service to Riverside.",
  "This is the last chance to transfer to Green Line service to Riverside and Heath Street.",
  "This is the last chance to transfer to Green Line service to Boston College.",
  "This is the last chance to transfer to Green Line service to Union Square.",
  "This is the last chance to transfer to Green Line service to Medford/Tufts.",
  "Front door only.",
  "Front door service only.",
  "Stand clear of the closing doors.",
  "For elevator access, exit to the left",
  "For elevator access, exit to the right",
  "For elevator access, exit to the left or right",
  "For elevator access, exit to the left onto the center platform",
  "Please request your stop for all street-level stations."
]

announcements = prefixes ++ stops ++ prefixed_stops ++ advisories

output_dir = Path.join([File.cwd!(), "output", "type_9"])

GlType9Announcements.synthesize_all_to_files(announcements, output_dir)
