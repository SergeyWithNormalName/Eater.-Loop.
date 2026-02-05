extends RefCounted

const TestUtils = preload("res://tests/test_utils.gd")

var _failures: Array[String] = []
var utils = TestUtils.new()

func fail(message: String) -> void:
    _failures.append(message)

func assert_true(condition: bool, message: String) -> void:
    if not condition:
        fail(message)

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
    if actual != expected:
        if message == "":
            message = "Expected %s, got %s" % [str(expected), str(actual)]
        fail(message)

func assert_loads(path: String) -> Variant:
    if not ResourceLoader.exists(path):
        fail("Missing resource: %s" % path)
        return null
    var res = load(path)
    if res == null:
        fail("Failed to load resource: %s" % path)
    return res

func get_failures() -> Array[String]:
    return _failures
