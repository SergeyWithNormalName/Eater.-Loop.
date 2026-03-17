# Игровая архитектура и руководство по рефакторингу

Коротко: это Godot-игра, где игровая логика, timing и визуальные эффекты не меняются в рамках архитектурных правок. Мы фиксируем только то, как устроены системы, как их тестировать и какие привычки нельзя нарушать.

## Как запустить
- `godot --headless -s res://tests/run_tests.gd` — полный smoke/runtime-раннер (сейчас покрывает 51 тест и архитектурные контракты).
- `GODOT_BIN=/path/to/Godot bash tests/run_tests.sh` — вспомогательный скрипт, который учитывает переменные окружения.

## Ключевые системы
- `GameState`/`CycleState` — разделяют persistent state (run, checkpoint) и per-cycle метрики.
- `GameDirector` — фасад, управляющий `DistortionPhaseController`, `ScreenFxOverlayController`, `DeathSequenceController` и таймерами.
- `MinigameController` + gamepad-система — единый runtime для всех мини-игр.
- `InteractiveObject` и `InteractableAvailabilityVisual` — контракт интерактивных объектов, `SceneRuleRunner` — декларативный wiring.
- `PoweredSwitchableInteractable` — единый API для ламп, проекторов и генератора.

## Правила рефакторинга
- Не меняй `GameDirector` API в рамках текущей задачи; вместо этого добавляй контроллеры и расширяй фасад.
- Используй `InteractiveObject.locked_message` вместо локальных `door_locked_message`. Звук интеракции идёт через `play_feedback_sfx`.
- `SceneRuleRunner` заменяет `has_method/call`-шаблоны в уровнях; каждый rule — типизированный `SceneRuleAction`.
- Не трогай shader/music timings (feeding, death overlay, distortion fade, bedtime transition).
- Соблюдай тестовую стратегию: добавляй characterization tests перед рефакторингом и держи `tests/run_tests.gd` зелёным.

## Что делать при добавлении контента
1. Новый interactable? Расширь `InteractiveObject`, используй `play_feedback_sfx(...)` и `InteractableAvailabilityVisual` при необходимости, избегай ad-hoc audio-плееров.
2. Новый level или event? опиши wiring через `SceneRuleRunner`, а сложные эффекты подключи через контроллеры GameDirector.
3. Новый state/flag? обнови `GameState`, собери checkpoint и триггеры, добавь тесты на `CycleState` и checkpoint recovery.

## Документация
- `docs/architecture_overview.md` — быстрый обзор и ссылка на специализированные темы.
- `docs/interaction_system.md` — интерактивный контракт, availability visual, feedback audio, powered interactables.
- `docs/state_and_checkpoint_system.md` — run-vs-cycle state, autosave, pending respawns.
- `docs/level_event_system.md` — `SceneRuleRunner`, action-фабрика, пример wiring.
- `docs/refactor_safety_rules.md` — инварианты, которые нельзя нарушать.
- `docs/testing_strategy.md` — какие тесты есть, какие добавить перед изменениями.
