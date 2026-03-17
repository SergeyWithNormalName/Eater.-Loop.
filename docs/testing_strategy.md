# Стратегия тестирования

## Существующий набор
- Smoke/static: `tests/test_scripts_compile.gd`, `test_autoloads.gd`, `test_project_config.gd`, `test_scenes_load.gd`.
- Архитектурные: `test_interaction_architecture_contracts.gd`, `test_musicmanager_private_api_usage.gd`, `test_light_adds_directional_contract.gd` и другие, перечисленные в `tests/README.md`.
- Runtime: `test_audio_*`, `test_minigame_*`, `test_cycle_state_*`, `test_fridge_*`, `test_laptop_*`, `test_generator_*`, `test_final_feed_minigame_stage_transition` и подобные.
- Архитектурные runtime-характеризации: `test_game_director_runtime.gd`, `test_scene_rule_runner.gd`, `test_interactive_object_feedback_audio.gd`.

## Куда добавлять characterization tests
1. `Fridge`: access code success/cancel/fail, unique intro once-per-run, teleport-on-success, autosave run, idle rocking hooking.
2. `InteractiveObject`: prompt lifecycle, checkpoint capture/apply, feedback audio (verify `play_feedback_sfx` hits `AudioStreamPlayer` once), managed minigame attach, `set_interaction_enabled` toggling.
3. `Door`/`Phone`/`Obstacle`: locked/unlocked, cleanup on abort, ringtone/pick checkpoint, obstacle progress reset.
4. `GameDirector`: timer → distortion, minigame deferral, death overlay (custom vs default), FX reset across scene changes.
5. `SceneRuleRunner`: ready-triggered actions, signal-triggered actions, one-shot behavior, safe no-op when nodes missing.

## Static guards
- Продолжать `test_interaction_architecture_contracts.gd`: держать migrated-файлы без `has_method(`/`call(` и без ссылок на `archive(trash)`.
- Проверка ссылок на `archive(trash)` должна оставаться, а при миграции новых wiring-файлов их нужно добавлять в список typed-contract guard-ов.

## Регрессия и документация
- Перед любым рефакторингом добавляйте аналогичный тест или обновляйте `docs/testing_strategy.md`.
- Если добавляете новый architecture test, синхронизируйте `tests/README.md` и `docs/architecture_overview.md`.
