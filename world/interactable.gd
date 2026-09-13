class_name Interactable
extends StaticBody3D
## Anything the crosshair can target with E. The host acts on `interact_id`;
## players see `interact_text()` as the prompt.

var interact_id := ""
var prompt := ""
## Optional func(player) -> String for prompts that depend on state or what you hold.
var text_provider: Callable


func interact_text(player: Node) -> String:
	if text_provider.is_valid():
		return text_provider.call(player)
	return prompt


## Seconds E must be held (0 = press once).
func hold_seconds(_player: Node) -> float:
	return 0.0
