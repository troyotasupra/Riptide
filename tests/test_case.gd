extends RefCounted
## Minimal assertion base for headless tests. Suites extend this file.

var errors: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)


func near(actual: float, expected: float, epsilon: float, message: String) -> void:
	if absf(actual - expected) > epsilon:
		errors.append("%s (expected %.4f ± %.4f, got %.4f)" % [message, expected, epsilon, actual])
