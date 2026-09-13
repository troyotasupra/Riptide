extends "res://tests/test_case.gd"

const DayNightScript = preload("res://world/day_night.gd")
const TempScript = preload("res://world/environment_temp.gd")


func test_noon_is_bright_and_midnight_is_dark() -> void:
	var noon: float = (DayNightScript.SUNRISE + DayNightScript.SUNSET) * 0.5
	var midnight := fposmod(DayNightScript.SUNSET + (1.0 - (DayNightScript.SUNSET - DayNightScript.SUNRISE)) * 0.5, 1.0)
	near(DayNightScript.sun_elevation(noon), 1.0, 0.001, "sun overhead at noon")
	near(DayNightScript.daylight(noon), 1.0, 0.001, "full daylight at noon")
	check(DayNightScript.sun_elevation(midnight) < -0.9, "sun far below at midnight")
	near(DayNightScript.daylight(midnight), 0.0, 0.001, "dark at midnight")


func test_clock_reads_like_a_day() -> void:
	check(DayNightScript.clock_text(DayNightScript.SUNRISE) == "06:00", "sunrise at 06:00")
	check(DayNightScript.clock_text(DayNightScript.SUNSET) == "20:00", "sunset at 20:00")
	check(DayNightScript.clock_hours(0.0) < 6.0 and DayNightScript.clock_hours(0.0) > 0.0, "early hours before sunrise")


func test_day_is_fourteen_minutes() -> void:
	var daylight_seconds: float = (DayNightScript.SUNSET - DayNightScript.SUNRISE) * DayNightScript.DAY_LENGTH
	near(daylight_seconds, 14.0 * 60.0, 0.5, "14 minutes of daylight")


func test_time_of_day_follows_the_clock_and_offset() -> void:
	near(DayNightScript.time_of_day(0.0, 0.25), 0.25, 0.0001, "offset sets the start")
	near(DayNightScript.time_of_day(DayNightScript.DAY_LENGTH * 1.5, 0.0), 0.5, 0.0001, "wraps each day")


func test_nights_and_soaking_feel_colder() -> void:
	check(TempScript.felt_temp(0.0, 0.0, false) < TempScript.felt_temp(1.0, 0.0, false), "night is colder than day")
	check(TempScript.felt_temp(1.0, 1.0, false) < TempScript.felt_temp(1.0, 0.0, false), "wet is colder than dry")
	check(TempScript.felt_temp(1.0, 1.0, true) < TempScript.felt_temp(1.0, 1.0, false), "in the water is coldest")
