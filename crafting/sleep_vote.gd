class_name SleepVote
extends RefCounted
## When the night gets skipped: a strict majority of the crew in bed starts a
## countdown, so one person staying up can't hold everyone hostage, and one
## person going to bed can't skip the night on everyone else.

const COUNTDOWN := 30.0
## Nobody is left standing: the night goes straight away.
const COUNTDOWN_ALL := 5.0


static func needed(crew_size: int) -> int:
	return maxi(1, crew_size / 2 + 1)


## How long the crew waits before the night is skipped, once enough are in bed.
static func countdown(asleep: int, crew_size: int) -> float:
	return COUNTDOWN_ALL if asleep >= maxi(1, crew_size) else COUNTDOWN


static func enough(asleep: int, crew_size: int) -> bool:
	return asleep >= needed(crew_size)
