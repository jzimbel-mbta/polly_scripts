defmodule GlStationNames do
  @moduledoc """
  Synthesizes all Green Line station names, and converts them from mp3 to
  wav, as well as to a lower bitrate mono-channel wav.
  """

  alias PollyScripts.Polly

  def synthesize_all_to_files(station_names, output_dir) do
    mp3_dir = Path.join(output_dir, "mp3")
    wav_dir = Path.join(output_dir, "wav")
    compliant_wav_dir = Path.join(output_dir, "compliant_wav")
    prepare_dir(mp3_dir)
    prepare_dir(wav_dir)
    prepare_dir(compliant_wav_dir)

    failed =
      station_names
      |> Task.async_stream(&synthesize_to_file(&1, mp3_dir), timeout: :infinity)
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.zip(station_names)
      |> Enum.flat_map(fn
        {:ok, _} -> []
        {error, name} -> [{name, error}]
      end)

    case failed do
      [] ->
        IO.puts("TTS synthesis succeeded.")

      failed ->
        IO.puts("#{length(failed)} station names failed to synthesize to file.")
        Enum.each(failed, fn {name, error} -> IO.inspect(error, label: name) end)
    end

    wav_results = convert_all_to_wav(mp3_dir, wav_dir)
    compliant_wav_results = convert_all_to_wav(mp3_dir, compliant_wav_dir, ~w[-ar 11025 -ac 1])

    wav_results
    |> Enum.reject(&match?({_, 0}, &1))
    |> Enum.map(&elem(&1, 0))
    |> case do
      [] ->
        IO.puts("wav conversion succeeded.")

      failed ->
        IO.puts(
          "#{length(failed)} mp3 files failed to convert to wav. Failed to produce the following:"
        )

        Enum.each(failed, &IO.inspect/1)
    end

    compliant_wav_results
    |> Enum.reject(&match?({_, 0}, &1))
    |> Enum.map(&elem(&1, 0))
    |> case do
      [] ->
        IO.puts("compliant wav conversion succeeded.")

      failed ->
        IO.puts(
          "#{length(failed)} mp3 files failed to convert to wav. Failed to produce the following:"
        )

        Enum.each(failed, &IO.inspect/1)
    end
  end

  defp prepare_dir(dir_path) do
    File.rm_rf!(dir_path)
    File.mkdir_p!(dir_path)
  end

  defp synthesize_to_file(station_name, output_dir) do
    station_name
    |> clean_up_text_for_synthesis()
    |> Polly.synthesize()
    |> case do
      {:ok, audio_data} ->
        station_name
        |> get_file_path(output_dir)
        |> File.write(audio_data)

      error ->
        error
    end
  end

  defp convert_all_to_wav(mp3_dir, wav_dir, conversion_args \\ []) do
    mp3_dir
    |> File.ls!()
    |> Enum.map(&Path.join(mp3_dir, &1))
    |> Enum.map(&mp3_to_wav(&1, wav_dir, conversion_args))
  end

  defp mp3_to_wav(mp3_path, wav_dir, conversion_args) do
    wav_path =
      mp3_path
      |> Path.basename(".mp3")
      |> then(fn filename -> Path.join(wav_dir, filename <> ".wav") end)

    cmd_args = ["-i", mp3_path] ++ conversion_args ++ [wav_path]

    {_, exit_status} = System.cmd("ffmpeg", cmd_args, stderr_to_stdout: true)

    {wav_path, exit_status}
  end

  defp get_file_path(station_name, output_dir) do
    Path.join(output_dir, sanitize_filename(station_name) <> ".mp3")
  end

  defp clean_up_text_for_synthesis(text) do
    String.replace(text, ~r|/|, ", ")
  end

  defp sanitize_filename(string) do
    string
    |> String.replace(~r|[/\s]|, "-")
    |> String.replace(~r|[\.'??,:]|, "")
  end
end

station_names = [
  "College Avenue",
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
  "Fenwood Road",
  "Mission Park",
  "Riverway",
  "Back of the Hill",
  "Heath Street"
]

output_dir = Path.join([File.cwd!(), "output", "gl_station_names"])

GlStationNames.synthesize_all_to_files(station_names, output_dir)
