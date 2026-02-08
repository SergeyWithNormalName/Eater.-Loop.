# Система музыки и звука

Документ описывает текущую архитектуру аудио в проекте и правильное использование
`MusicManager`, `LevelMusic` и `TriggerSetProperty`.

## Быстрый обзор

- Вся музыка проходит через autoload `MusicManager` (`res://levels/music_manager.gd`).
- SFX должны идти в шину `Sounds`.
- Музыка уровня обычно запускается через `LevelMusic` (`res://levels/cycles/level_music.gd`).
- Временные музыкальные состояния (события, мини-игры, искажения) используют стек
  (`push_music` / `pop_music`).
- `TriggerSetProperty` умеет управлять музыкой, но нужно правильно сочетать действия
  входа и выхода.

## Шины (Audio Buses)

В проекте используются две ключевые шины:

- `Music` — весь музыкальный контент (уровень, мини-игры, погоня, меню).
- `Sounds` — все эффекты (шаги, интеракции, UI-звуки).

Проверка/создание шин выполняется в `SettingsManager` на старте игры.

## Mix Settings

Ресурс `res://music/music_mix_settings.tres` (`MusicMixSettings`) задает оффсеты
громкости (дБ) по категориям:

- `ambient`
- `distortion`
- `event`
- `chase`
- `minigame`
- `pause`
- `menu`

`MusicManager` автоматически применяет эти оффсеты во всех типовых обертках
(`play_ambient_music`, `start_event_music`, и т.д.).

## MusicManager (autoload)

`MusicManager` — единая точка управления музыкой. Основа системы:

- два `AudioStreamPlayer` для кроссфейда базовой музыки;
- стек временных состояний;
- отдельные потоки для музыки погони и pause-menu;
- поддержка duck/pause/resume.

### 1) Базовое воспроизведение

```gdscript
MusicManager.play_music(stream, fade_time, volume_db)
MusicManager.stop_music(fade_time)
```

`play_music` делает кроссфейд между текущим и новым треком.

### 2) Временная музыка через стек

```gdscript
MusicManager.push_music(stream, fade_time, volume_db)
# ... временный контент ...
MusicManager.pop_music(fade_time)
```

`pop_music` возвращает предыдущий трек, позицию и состояние ducking.

### 3) Типовые обертки

- Уровень (ambient): `MusicManager.play_ambient_music(...)`
- Главное меню: `MusicManager.play_menu_music(...)`
- Искажения: `MusicManager.start_distortion_music(source, stream, fade, volume)` /
  `MusicManager.stop_distortion_music(source, fade)`
- Событие: `MusicManager.start_event_music(source, stream, fade_in, volume, fade_out)` /
  `MusicManager.stop_event_music(source, fade_out)`
- Мини-игра: `MusicManager.start_minigame_music(stream, volume)` /
  `MusicManager.stop_minigame_music()`
- Pause menu: `MusicManager.start_pause_menu_music(stream, fade_out, volume)` /
  `MusicManager.stop_pause_menu_music(fade_in)`

### 4) Пауза и возобновление всей музыки

```gdscript
MusicManager.pause_all_music(fade_time)
MusicManager.resume_all_music(fade_time)
```

Это именно pause/resume, а не изменение громкости.

### 5) Ducking (приглушение)

```gdscript
MusicManager.duck_music(fade_time, volume_db)
MusicManager.restore_music_volume(fade_time)
```

Это изменение громкости базовой музыки без паузы потока.

### 6) Музыка погони

```gdscript
MusicManager.set_chase_music_source(self, true, stream, volume_db, fade_out_time)
MusicManager.set_chase_music_source(self, false)
```

Пока есть хотя бы один активный источник погони, базовая музыка быстро
приглушается/глушится и возвращается после окончания погони.

## LevelMusic (музыка уровня)

`res://levels/cycles/level_music.gd` на `_ready()` вызывает:

```gdscript
MusicManager.play_ambient_music(stream, fade_time, volume_db)
```

Параметры:

- `play_on_ready` — запускать ли музыку при старте сцены.
- `continue_on_level_change` — останавливать ли ambient при выходе из уровня.

## TriggerSetProperty: управление музыкой

Сцена/скрипт:

- `res://objects/interactable/trigger/trigger_set_property.tscn`
- `res://objects/interactable/trigger/trigger_set_property.gd`

### Важные флаги триггера

- `affect_on_enter` (по умолчанию `true`) — применять изменения при входе.
- `affect_on_exit` (по умолчанию `false`) — применять изменения при выходе.
- `one_shot` (по умолчанию `true`) — после первого срабатывания триггер больше не работает.
- `apply_on_ready_if_overlapping` (по умолчанию `false`) — применить вход сразу на старте,
  если игрок уже стоит внутри зоны.

### Действия музыки (`music_on_enter` / `music_on_exit`)

- `0` Не менять
- `1` Подменить трек -> `MusicManager.play_music(...)`
- `2` Заглушить -> `MusicManager.duck_music(...)`
- `3` Восстановить -> `MusicManager.restore_music_volume(...)`
- `4` Приоритетный трек (старт) -> `MusicManager.start_event_music(...)`
- `5` Приоритетный трек (стоп) -> `MusicManager.stop_event_music(...)`
- `6` Пауза всей музыки -> `MusicManager.pause_all_music(...)`
- `7` Возобновить музыку -> `MusicManager.resume_all_music(...)`

### Корректные пары "вход -> выход"

- `2 (Заглушить)` -> `3 (Восстановить)`
- `4 (Event start)` -> `5 (Event stop)`
- `6 (Пауза)` -> `7 (Возобновить)`

Неправильная пара (частая ошибка):

- `6 (Пауза)` -> `3 (Восстановить)`

`restore_music_volume` снимает только ducking, но не снимает pause состояния.

## Кейс: музыка выключена в спальне, включена в остальном уровне

Если игрок стартует внутри спальни, рекомендуемая настройка `TriggerSetProperty`:

- `affect_on_enter = true`
- `affect_on_exit = true`
- `one_shot = false`
- `apply_on_ready_if_overlapping = true`
- `music_enabled = true`
- `music_on_enter = 6` (Пауза всей музыки)
- `music_on_exit = 7` (Возобновить музыку)

Это гарантирует:

- на старте в спальне музыка не играет;
- после выхода из спальни музыка возобновляется;
- при повторном входе/выходе поведение сохраняется.

## Типовые ошибки и диагностика

1. Музыка отключается, но не возвращается:
- Проверить `affect_on_exit` — должен быть `true`.
- Проверить пару действий: если вход `6`, выход должен быть `7`.

2. Игрок стартует внутри зоны, но вход не применился:
- Включить `apply_on_ready_if_overlapping = true`.
- Проверить, что игрок в группе `player` (по умолчанию в `player.tscn` так и есть).

3. Триггер срабатывает только один раз:
- Проверить `one_shot`. Для зонового поведения нужен `false`.

4. Кажется, что команда сработала, но громкость не та:
- Проверить оффсеты в `MusicMixSettings`.
- Проверить, какая шина/какой поток реально играет (`Music`, chase, pause, event).

## SFX (звуки)

Для одноразовых эффектов используйте шину `Sounds`:

```gdscript
var player := AudioStreamPlayer.new()
player.bus = "Sounds"
player.stream = some_stream
player.play()
```

Для UI-звуков можно использовать `UIMessage.play_sfx(...)`.
