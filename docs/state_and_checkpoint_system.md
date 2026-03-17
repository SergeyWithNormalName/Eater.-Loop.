# Состояния и чекпоинты

## Разделение `GameState` ↔ `CycleState`
- `GameState` — персистентный run: last_scene_path, unique_feeding_intro_played, flashlight_unlocked, autosave, checkpoint snapshots.
- `CycleState` — runtime-флаги: `phases`, `ate_this_cycle`, `lab_done`, `completed_labs`, `fridge_interacted`, `pending_sleep_spawn`, `pending_respawn_blackout`, `electricity_on`, `flashlight_collected_this_cycle`.
- Взаимодействие происходит только через публичные методы (`mark_ate`, `has_eaten_this_cycle`, `queue_respawn_blackout`, `has_completed_all_labs`, `autosave_run`). Строго запрещены прямые мутации полей.

## Checkpoint-flow
- `GameState.capture_fridge_checkpoint` / `capture_level_start_checkpoint` собирают snapshot через `CheckpointStateUtils.capture_node_snapshot`.
- `GameState.apply_checkpoint_to_scene` восстанавливает `GameDirector`, `CycleState`, сцену, а потом вызывает `CheckpointStateUtils.apply_node_snapshot`.
- `CycleState.apply_checkpoint_state` вовлекает `electricity_on` и `flashlight_collected_this_cycle` — т.е. любые интерактивные объекты должны подписываться на сигналы `cycle_state_reset` / `fridge_interacted_changed`.

## Pending-флаги
- `queue_sleep_spawn` / `consume_pending_sleep_spawn` — для скрытого телепорта на сон.
- `queue_respawn_blackout` / `consume_pending_respawn_blackout` — для принудительного fade-in на респавне.
- `pending_sleep_spawn`/`respawn_blackout` всегда сохраняются в `GameState`.

## Тесты и документация
- Любые изменения в state/checkpoint должны сопровождаться тестами `test_save_state_split`, `test_respawn_checkpoint_restore`, `test_level_checkpoint_spawn`, а также обновлением `docs/testing_strategy.md`.
