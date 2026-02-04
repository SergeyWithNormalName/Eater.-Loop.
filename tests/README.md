# Godot smoke tests

These tests are lightweight smoke checks for project health. They run headless and focus on:
- Main scene is configured and loadable.
- Autoloads exist and load.
- Core scenes load and instantiate (excluding archived/trash folders).
- All scripts compile.
- Key input actions exist and have events.

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

## Notes

- These are smoke tests; they do not simulate gameplay.
- If you add/remove core input actions, update `tests/cases/test_input_actions.gd`.
- If you add new scene folders, include them in `tests/cases/test_scenes_load.gd`.
