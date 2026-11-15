class_name TestCase
extends RefCounted
## 极简测试基类。每个 test_ 方法在新实例上运行，失败记录到 failures。

var failures: PackedStringArray = PackedStringArray()
var current := ""


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [current, message])


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: 期望 %s，实际 %s %s" % [current, str(expected), str(actual), message])


func check_near(actual: float, expected: float, epsilon: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > epsilon:
		failures.append("%s: 期望 %f±%f，实际 %f %s" % [current, expected, epsilon, actual, message])
