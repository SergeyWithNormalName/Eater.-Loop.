# Система интеракций

## Контракт `InteractiveObject`
- Управляет подсказками (`show_prompt`/`hide_prompt`), входом, зависимостями, `one_shot` и флагами `handle_input/auto_prompt`.
- Публичные методы: `request_interact()`, `complete_interaction()`, `attach_minigame()`, `start_managed_minigame()`, `set_dependency_object()`, `set_interaction_enabled()`, `refresh_interaction_state()`, `play_feedback_sfx(...)`.
- Любой объект должен обращаться к `locked_message`, если зависимость не выполнена, и использовать `interaction_finished`/`interaction_requested` вместо строковых `has_method`.

## `play_feedback_sfx(...)`
- Используется всеми интерактивными объектами вместо индивидуальных `AudioStreamPlayer`:
  `play_feedback_sfx(stream, volume_db := 0.0, pitch_min := 1.0, pitch_max := 1.0)`.
- Параметры позволяют варьировать громкость и питч, не дублируя создание плееров.

## `InteractableAvailabilityVisual`
- Вспомогательный `RefCounted`, который инкапсулирует: спрайты locked/available, indicator lights и optional looping noise.
- Сам ни на что не подписывается: владелец (`Fridge`, `Laptop` и будущие объекты) вызывает `configure(...)` и затем `apply(is_available)` из своих `_ready()`/`refresh_interaction_state()`-веток.

## `PoweredSwitchableInteractable`
- Базовый узел для ламп/проекторов: содержит `set_powered(bool)`, `is_powered`, `turn_on` (обёртка для совместимости) и `requires_generator`.
- Звук переключения делается через `play_feedback_sfx`; специфичное поведение вроде flicker остаётся в наследниках (`Lamp`).
- `Generator` вызывает `set_powered(true)` на группе `generator_required_light` через публичный API, а не `has_method("turn_on")`.
