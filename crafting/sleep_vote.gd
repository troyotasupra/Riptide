class_name SleepVote
extends RefCounted
## When the night gets skipped: a strict majority of the crew in bed starts a
## countdown, so one person staying up can't hold everyone hostage, and one
## person going to bed can't skip the night on everyone else.

const COUNTDOWN := 30.0


static func needed(crew_size: int) -> int:
	return maxi(1, crew_size / 2 + 1)


static func enough(asleep: int, crew_size: int) -> bool:
	return asleep >= needed(crew_size)
