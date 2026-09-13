extends Node
## The shared ocean clock. Everyone must evaluate waves at the same moment or
## boats float on water that isn't where you see it. The host's clock is truth.
##
## Clients run slightly behind the host (PRESENTATION_DELAY) so that boat
## snapshots for the moment they are drawing have already arrived. Waves are
## drawn at that same delayed time, so hulls and swells always line up.

const PRESENTATION_DELAY := 0.1

var time := 0.0


func _process(delta: float) -> void:
	time += delta


func sync_from_host(host_time: float) -> void:
	var target := host_time - PRESENTATION_DELAY
	var error := target - time
	if absf(error) > 0.5:
		time = target
	else:
		time += error * 0.25
