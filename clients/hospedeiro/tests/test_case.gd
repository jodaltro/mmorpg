class_name TestCase
extends RefCounted
## Minimal headless test base. Methods named test_* run in order; they may await.

var tree: SceneTree
var failures: Array[String] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(cond: bool, message: String = "expected true") -> void:
	if not cond:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%s expected %s but got %s" % [message, str(expected), str(actual)])


func assert_near(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s expected %s +/- %s but got %s" % [message, str(expected), str(tolerance), str(actual)])
