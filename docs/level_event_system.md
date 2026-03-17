# Система событий уровней

## SceneRuleRunner
- Компонент привязывается к сцене и слушает либо момент собственной готовности (`SceneRule.TriggerKind.READY`), либо конкретный сигнал с указанного `source_path`.
- `SceneRuleRunner` обеспечивает: ordered actions, `one_shot`, безопасное игнорирование отсутствующих узлов и единый `resolve_node()` сначала относительно самого runner, затем относительно level-host-а.
- На текущий момент поддерживаются только `READY` и `SIGNAL`; отложенные, расписанные или параллельные action-цепочки не реализованы и не должны документироваться как существующие.

## SceneRuleAction-ы
- `SetDependencyAction` — настраивает `dependency_object` и перезапускает `refresh_interaction_state`.
- `SetInteractionEnabledAction` — включает/выключает интерактивность через `set_interaction_enabled`.
- `SetDoorTargetAction` — обновляет `Door.set_target_marker_path` и автоматически переустанавливает `locked_message`.
- `SetLockedAction` — выставляет `is_locked` + optional message.
- `RefreshInteractionStateAction` — вызывает `refresh_interaction_state()` на интерактивных объектах, чтобы prompt перестроился.
- `SetPropertyAction` — универсально изменяет поле на указанное значение через `set(property_name, value)`.
- `ShowNotificationAction` — показывает сообщение через `UIMessage`.
- `SetDoorTargetFromCycleStateAction` — выбирает цель двери из `CycleState` по номеру цикла, сохраняя level-specific развилку вне скрипта уровня.
- `StartCrazyLevelEventAction` — типизированно вызывает `CrazyLevelEvent.start_event()`, без строковых `call(...)`.

## Примеры
- `level_07_doors.tscn`: перестроено с помощью `SceneRuleRunner`, который отключает/включает двери и выставляет `locked_message` на обе.
- `level_12_stu_2.tscn`: wiring генератора → холодильника и смена двери реализуется action-последовательностью, а не `call("set_dependency_object")`.
- `level_13_stu_3.tscn`: наблюдает за несколькими fridge-ами через один runner и обновляет цель двери в зависимости от `CycleState`.

## Наследуемость
- Action-ы реализуются как `Resource` с `execute(runner, args := [])`; новые action-ы добавляются сюда и документируются в `docs/architecture_overview.md`.
