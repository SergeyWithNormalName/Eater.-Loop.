extends SceneTree

const TEST_DIR := "res://tests/cases"

func _initialize() -> void:
    var failures: Array[String] = []
    var test_paths = _discover_tests()
    if test_paths.is_empty():
        failures.append("No tests found in %s" % TEST_DIR)
    else:
        for path in test_paths:
            var test_failures = _run_test(path)
            for message in test_failures:
                failures.append("%s: %s" % [path.get_file(), message])

    _report(failures)
    quit(failures.size())

func _discover_tests() -> Array[String]:
    var tests: Array[String] = []
    var dir = DirAccess.open(TEST_DIR)
    if dir == null:
        return tests
    dir.list_dir_begin()
    var name = dir.get_next()
    while name != "":
        if not dir.current_is_dir() and name.ends_with(".gd"):
            if name.begins_with("test_"):
                tests.append(TEST_DIR.path_join(name))
        name = dir.get_next()
    dir.list_dir_end()
    tests.sort()
    return tests

func _run_test(path: String) -> Array[String]:
    var script = load(path)
    if script == null:
        return ["Failed to load test script"]
    var test = script.new()
    if not test.has_method("run"):
        return ["Test script has no run()"]
    var result = test.run()
    if result == null and test.has_method("get_failures"):
        return test.get_failures()
    if result is Array:
        return result
    return ["run() returned unexpected value"]

func _report(failures: Array[String]) -> void:
    if failures.is_empty():
        print("OK: all tests passed (", _discover_tests().size(), ")")
        return
    printerr("FAIL: ", failures.size(), " failure(s)")
    for message in failures:
        printerr(" - ", message)
