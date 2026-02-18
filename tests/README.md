# Godot smoke tests

These tests are lightweight smoke checks for project health. They run headless and focus on:
- Main scene is configured and loadable.
- Autoloads exist and load.
- Core scenes load and instantiate (excluding archived/trash folders).
- All scripts compile.
- Key input actions exist and have events.
- Runtime regressions for critical audio transitions (including menu -> level start).

## Run

From the project root:

```bash
godot --headless -s res://tests/run_tests.gd
```

Or use the helper script (respects `GODOT_BIN`):

```bash
GODOT_BIN=/path/to/Godot bash tests/run_tests.sh
```

Exit code is the number of failures (0 = success).

## Async runtime tests

- The runner supports both sync and async `run()` tests.
- Async tests are used for frame-based/runtime checks that cannot be validated by static file parsing.
- Each test has a per-test timeout in `tests/run_tests.gd` (`TEST_TIMEOUT_SECONDS`) so a hung scenario does not stall CI forever.
- Prefer keeping async tests deterministic and short (target: total suite under ~40s).

## Notes

- These are smoke tests; they do not simulate gameplay.
- Runtime tests should clean up their scene/autoload side effects before returning.
- If you add/remove core input actions, update `tests/cases/test_input_actions.gd`.
- If you add new scene folders, include them in `tests/cases/test_scenes_load.gd`.
