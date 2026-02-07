# Система геймпада для мини-игр

Документ описывает новую централизованную систему управления мини-играми с геймпада без эмуляции курсора.

## Цели
- Полное прохождение игры и мини-игр на Steam Deck без мыши.
- Единый runtime для управления фокусом/навигацией.
- Отсутствие дублирования логики управления в каждой мини-игре.
- Сохранение существующего mouse/keyboard UX.

## Ключевые модули
- `res://levels/minigames/minigame_controller.gd`
  - Управляет жизненным циклом мини-игры (пауза, музыка, таймер, cancel).
  - Хранит/применяет схему геймпада через:
    - `set_gamepad_scheme(minigame: Node, scheme: Dictionary)`
    - `clear_gamepad_scheme(minigame: Node)`
- `res://levels/minigames/gamepad/gamepad_runtime.gd`
  - Выполняет схему активной мини-игры.
  - Режимы:
    - `focus`: выбор одного элемента и подтверждение.
    - `pick_place`: выбор источника и последующее размещение в цель.
- `res://levels/minigames/gamepad/gamepad_spatial_nav.gd`
  - Spatial-навигация между элементами по направлению.
- `res://levels/minigames/gamepad/gamepad_highlighter.gd`
  - Визуальная подсветка активного/выбранного элемента.
- `res://levels/minigames/gamepad/gamepad_hint_bar.gd`
  - Нижняя панель подсказок кнопок (A/B/X/LB/RB).

## Формат схемы (`scheme`)
Схема передаётся словарём в `MinigameController.set_gamepad_scheme(...)`.

### Общие поля
- `mode: String`
  - `"focus"` или `"pick_place"`.
- `hints: Dictionary`
  - Опциональные подписи для кнопок:
    - `confirm`, `cancel`, `secondary`, `tab_left`, `tab_right`.

### Режим `focus`
- Источник элементов:
  - `focus_nodes: Array[Node]` или `focus_provider: Callable -> Array[Node]`
- Колбэки:
  - `on_confirm(active: Node, context: Dictionary) -> bool`
  - `on_secondary(active: Node, context: Dictionary) -> bool` (опционально)
  - `on_focus_changed(active: Node, context: Dictionary)` (опционально)

### Режим `pick_place`
- Источники:
  - `source_nodes` или `source_provider`
- Цели:
  - `target_nodes` или `target_provider`
- Колбэки:
  - `on_pick(source: Node, context: Dictionary)` (опционально)
  - `on_place(source: Node, target: Node, context: Dictionary) -> bool`
  - `on_placed(source: Node, target: Node, context: Dictionary)` (опционально)
  - `on_cancel_pick(source: Node, context: Dictionary)` (опционально)
  - `on_secondary(active: Node, context: Dictionary) -> bool` (опционально)
  - `on_focus_changed(active: Node, context: Dictionary)` (опционально)

`context` содержит текущее состояние runtime:
- `mode`, `section`, `selected_source`, `active_node`,
- `focus_nodes`, `source_nodes`, `target_nodes`.

## Подключение к новой мини-игре (чеклист на ~10 минут)
1. В `_ready()` мини-игры вызвать `MinigameController.set_gamepad_scheme(self, ...)`.
2. В `_exit_tree()` обязательно вызвать `MinigameController.clear_gamepad_scheme(self)`.
3. Если элементы появляются динамически, использовать `*_provider` вместо фиксированного массива.
4. Для custom-нод без `Control` добавить:
   - `is_gamepad_focusable() -> bool` (при необходимости),
   - `get_gamepad_focus_rect() -> Rect2` (для точной навигации).
5. Не использовать `warp_mouse` и не привязывать геймпад к `gui_get_hovered_control()`.
6. Проверить, что `mg_cancel` закрывает мини-игру или отменяет текущий pick-state.

## Правила совместимости с мышью/клавиатурой
- Старое mouse/keyboard управление оставлять рабочим.
- Drag мышью должен обрабатываться mouse-событиями (`InputEventMouseButton`/`_gui_input`), а не `mg_grab`.
- Не удалять существующие UI кнопки/сигналы без необходимости.

## Набор input actions
Обязательные мини-игровые действия:
- `mg_confirm`, `mg_cancel`, `mg_secondary`
- `mg_nav_left`, `mg_nav_right`, `mg_nav_up`, `mg_nav_down`
- `mg_tab_left`, `mg_tab_right`

UI-навигация:
- `ui_accept`, `ui_cancel`, `ui_left`, `ui_right`, `ui_up`, `ui_down`

Системные действия:
- `pause_menu` (кнопка Menu/Start на геймпаде)

`mg_grab` оставлен только для старых mouse drag-кейсов.

## Steam Deck QA чеклист
- Полный запуск и прохождение без мыши.
- SQL: выбор слова -> выбор слота -> вставка, `X` очищает слот.
- LLM: кнопка генерации нажимается через `A`.
- Feeding: еда выбирается автоматически, `A` сразу отправляет текущий кусок в рот.
- Search Key: мусор сдвигается кнопкой, ключ берётся после освобождения.
- Code Lock: цифровые кнопки + `X` очистка + `B` отмена.
- Пауза и меню: навигация и подтверждение только геймпадом.
- Mouse/keyboard сценарии не сломаны.

## Troubleshooting
- `Нет фокуса`: проверьте, что provider возвращает видимые (`visible`) и не удаляемые ноды.
- `Кнопка не нажимается`: убедитесь, что `on_confirm` возвращает `true` при успешной обработке.
- `Навигация скачет`: реализуйте `get_gamepad_focus_rect()` для точных прямоугольников.
- `Cancel сразу закрывает мини-игру`: для `pick_place` runtime сам гасит выбранный source; проверьте, что схема в режиме `pick_place`.
- `Динамические ноды не видны runtime`: используйте `focus_provider/source_provider/target_provider`, а не статический массив.
- `Конфликт input actions`: убедитесь, что в `project.godot` есть все `mg_*` и `ui_*` действия с корректными биндами.
