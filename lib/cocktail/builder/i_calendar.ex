defmodule Cocktail.Builder.ICalendar do
  alias Cocktail.{Rule, Schedule}
  alias Cocktail.Validation.{Interval, Day, HourOfDay}

  def build(schedule) do
    rules =
      schedule.recurrence_rules
      |> Enum.map(&build_rule/1)

    start_time = build_start_time(schedule.start_time)
    end_time = build_end_time(schedule)

    [start_time] ++ rules ++ [end_time]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp build_time(time) do
    timezone = time.time_zone
    time_string = Timex.format!(time, "{YYYY}{0M}{0D}T{h24}{m}{s}")
    "TZID=#{timezone}:#{time_string}"
  end

  defp build_start_time(time) do
    time_string = time |> build_time
    "DTSTART;#{time_string}"
  end

  defp build_end_time(%Schedule{duration: nil}), do: nil
  defp build_end_time(%Schedule{start_time: start_time, duration: duration}) do
    time_string = Timex.shift(start_time, seconds: duration) |> build_time
    "DTEND;#{time_string}"
  end

  defp build_rule(%Rule{validations: validations}) do
    {parts, _} =
      [:interval, :day, :hour_of_day]
      |> Enum.reduce({[], validations}, &build_validation/2)
    "RRULE:" <> (parts |> Enum.reverse |> List.flatten |> Enum.join(";"))
  end

  defp build_validation(key, {parts, validations_kwl}) do
    validations = Keyword.get(validations_kwl, key)
    if is_nil(validations) do
      {parts, validations_kwl}
    else
      part = build_validation_part(key, validations)
      {[part | parts], validations_kwl}
    end
  end

  defp build_validation_part(:interval, [%Interval{interval: interval, type: type}]), do: build_interval(type, interval)
  defp build_validation_part(:day, days), do: days |> Enum.map(fn(%Day{day: day}) -> day end) |> build_days()
  defp build_validation_part(:hour_of_day, hours), do: hours |> Enum.map(fn(%HourOfDay{hour: hour}) -> hour end) |> build_hours()

  # intervals

  defp build_interval(type, 1), do: "FREQ=" <> build_frequency(type)
  defp build_interval(type, n), do: ["FREQ=" <> build_frequency(type), "INTERVAL=#{n}"]

  defp build_frequency(type), do: type |> Atom.to_string |> String.upcase

  # "day" validation

  defp build_days(days) do
    days_list =
      days
      |> Enum.sort
      |> Enum.map(&by_day/1)
      |> Enum.join(",")

    "BYDAY=#{days_list}"
  end

  defp by_day(0), do: "SU"
  defp by_day(1), do: "MO"
  defp by_day(2), do: "TU"
  defp by_day(3), do: "WE"
  defp by_day(4), do: "TH"
  defp by_day(5), do: "FR"
  defp by_day(6), do: "SA"

  # "hour of day" validation

  defp build_hours(hours) do
    hours_list =
      hours
      |> Enum.sort
      |> Enum.join(",")

    "BYHOUR=#{hours_list}"
  end
end