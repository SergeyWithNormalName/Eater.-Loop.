extends SceneTree

const TEST_DIR := "res://tests/cases"
const TEST_TIMEOUT_SECONDS := 15.0

func _initialize() -> void:
    await _run_all_tests()

func _run_all_tests() -> void:
    var failures: Array[String] = []
    var test_paths = _discover_tests()
    if test_paths.is_empty():
        failures.append("No tests found in %s" % TEST_DIR)
    else:
        for path in test_paths:
            var test_failures = await _run_test(path)
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
    var script_resource: Variant = load(path)
    if script_resource == null:
        return ["Failed to load test script"]
    if not (script_resource is Script):
        return ["Loaded resource is not a Script"]
    var script := script_resource as Script
    if not script.can_instantiate():
        return ["Test script cannot be instantiated"]
    var test: Object = script.new()
    if test == null:
        return ["Failed to instantiate test script"]
    if not test.has_method("run"):
        return ["Test script has no run()"]
    var result: Variant = test.call("run")
    if result is Object and result.has_signal("completed"):
        var state: Object = result
        if state.has_method("is_valid") and not bool(state.call("is_valid")):
            result = null
        else:
            var status := {"completed": false}
            state.connect("completed", func(_value = null) -> void:
                status["completed"] = true
            , Object.CONNECT_ONE_SHOT)
            var timeout := create_timer(TEST_TIMEOUT_SECONDS, true)
            var tick := create_timer(0.05, true)
            while not bool(status["completed"]) and timeout.time_left > 0.0:
                await tick.timeout
                tick = create_timer(0.05, true)
            if not bool(status["completed"]):
                return ["Timed out after %.1f sec" % TEST_TIMEOUT_SECONDS]
            result = null
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
