# Обновлённая карта архитектуры

Документ фиксирует технические границы, публичные API и вспомогательные реалии, которые нужно помнить при рефакторинге. Он остаётся союзником, а не справочником по поведению.

## 1. Autoload-маппинг и контроллеры
- `GameState` (`res://levels/cycles/game_state.gd`) — хранит run-персистентность, checkpoint-данные, сетевые селекторы и публичные мутации (`next_cycle`, `mark_{ate|fridge_interacted|phone_picked}`, `reset_run`, `capture_fridge_checkpoint` и т.п.).
- `CycleState` (`res://levels/cycles/cycle_state.gd`) — хранит runtime-флаги текущего цикла (labs, fridge, flashlight, pending respawn/sleep) и сигналами оповещает UI/levels.
- `GameDirector` (`res://levels/game_director.gd`) — фасад, оборачивающий три контроллера:
  * `DistortionPhaseController` — таймер и переключения NORMAL↔DISTORTED, дефер к мини-играм, spawn сталкера.
  * `ScreenFxOverlayController` — шифт/сдвиг камеры, damage-flash, light-only overlay, overlay-сцены с тенями.
  * `DeathSequenceController` — затемнение, shaders, retry-кнопка и custom-death hook.
- `MusicManager` (`res://levels/music_manager.gd`) — единственная точка для ambient/event/minigame/chase/priority-stack.
- `MinigameController` (`res://levels/minigames/minigame_controller.gd`) — жизненный цикл мини-игр, gamepad-схемы, блокировки движения и музыки.
- UI-сервисы: `UIMessage`, `InteractionPrompts`, `CursorManager`, `StaminaBar`, `FlashlightBar`, `CursorManager`

## 2. Контур интеракций
- `InteractiveObject` — единый публичный контракт. Он обрабатывает подсказки, ввод, зависимости, one-shot-политику, checkpoint-serialize и предоставляет `attach_minigame()`/`start_managed_minigame()`.
- `play_feedback_sfx(stream, volume_db := 0.0, pitch_min := 1.0, pitch_max := 1.0)` — публичный helper для звука интеракции. Не дублируйте `AudioStreamPlayer` в наследниках.
- `InteractableAvailabilityVisual` — компонент для переключения спрайтов и indicator-ламп, проигрывания looping noise и блокировки по состоянию. Используется холодильником, ноутбуком и другими сложными контентными узлами.
- `PoweredSwitchableInteractable` — базовый класс для энергозависимых объектов, предоставляющий `set_powered(enabled: bool)` и совместимость `turn_on()`.
- `Lamp`, `Projector` и `Generator` реализуют этот контракт: лампы реагируют на `powered` и настраиваемый flicker, проектор делится подсветкой, генератор содержит `set_powered(true)` и никак больше не вызывает `has_method("turn_on")`.

## 3. Mind the helpers
- `Fridge` разбивается на: лаб-контроль, уникальное вступление, feeding-flow, teleport/chase clear/autosave и `InteractableAvailabilityVisual`. Всё что остаётся внутри — упорядоченный pipeline: prerequisites → code lock → feeding → completion.
- Одноразовые опции `Fridge` теперь живут в отдельных resource-конфигах, а не в корне инспектора: `FridgeCodeLockConfig`, `FridgeLabRequirementConfig`, `FridgeTeleportConfig`, `FridgeUniqueIntroConfig`, `IdleRockingConfig`.
- `Laptop` держит базовый запуск SQL-мини-игры и completion-state, а вспомогательные политики (награда, unlock-on-dependency) выносятся в `LaptopCompletionReward` и `UnlockOnDependencyAttempt`.
- Денежная награда `Laptop` настраивается через `LaptopRewardConfig`, поэтому обычные ноутбуки не тащат reward-поля в каждый инстанс.
- `SceneRuleRunner` с ресурсами `SceneRuleAction` (`SetDependencyAction`, `SetInteractionEnabledAction`, `SetDoorTargetAction`, `SetLockedAction`, `RefreshInteractionStateAction`, `SetPropertyAction`, `ShowNotificationAction` и т.п.) заменяет level-specific `has_method/call` и делает wiring декларативным.

## 4. Контур уровней и событий
- Все levels/cycles/… держат `CycleLevel` как базу. Специфические wiring, ранее лежавшие в `_ready()`/`call_deferred(...)`, теперь оформляются через `SceneRuleRunner`.
- `CrazyLevelEvent` и аналогичные эффектные узлы остаются, но подключаются к `SceneRuleRunner` либо сигналам (например, `SceneRuleRunner` запускает `CrazyLevelEvent.start_event()`).

## 5. Границы API и инварианты
- Никаких `has_method("_private")` за пределами класса. Только публичные методы (`InteractiveObject`, `GameState`, `CycleState`, `MusicManager`, `GameDirector`).
- `InteractiveObject.locked_message` — canonical: наследники могут синхронизировать свои local message (например `door_locked_message` остаётся deprecated alias).
- Не вмешивайтесь в тайминги: shader transitions, feeding stages, music fades, teleport delays, bedtime fade должен работать как сейчас.
- Новые уровни и объекты обязательно проходят через `README.md`/`docs/testing_strategy.md`, чтобы знать, где фиксировать инварианты.

## 6. Ссылки на документацию
- `README.md` (корневой README) — навигационный хаб.
- `docs/interaction_system.md`, `docs/state_and_checkpoint_system.md`, `docs/level_event_system.md`, `docs/refactor_safety_rules.md`, `docs/testing_strategy.md` — углублённые справочники.

## 7. Ченджлог (на будущее)
- Добавлены `SceneRuleRunner` и `SceneRuleAction`.
- `GameDirector` теперь фасад, за ним контроллеры `DistortionPhaseController`, `ScreenFxOverlayController`, `DeathSequenceController`.
- `InteractiveObject` поставляет `play_feedback_sfx` и опосредует powered interactables через `PoweredSwitchableInteractable`.
- `Fridge`/`Laptop` используют вспомогательные компоненты и больше не хранят level-specific wiring.
