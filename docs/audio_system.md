# Система музыки и звука

Этот документ описывает, как в проекте устроено управление музыкой и звуками.

## Шины (Audio Buses)

В проекте используются две ключевые шины:

- **Music** — вся музыка (фон, мини‑игры, погони, меню).
- **Sounds** — все SFX (шаги, взаимодействия, UI‑звуки).

Создание/проверка шин выполняется в `SettingsManager` при старте игры.

## Mix Settings

Для типов музыки используется ресурс `res://music/music_mix_settings.tres` (`MusicMixSettings`).
Он задаёт оффсеты громкости (в дБ) по категориям:

- ambient, distortion, event, chase, minigame, pause, menu

Ресурс можно заменить в инспекторе `MusicManager`.

## MusicManager (autoload)

`MusicManager` — единая точка управления музыкой.

### Базовое воспроизведение

```gdscript
MusicManager.play_music(stream, fade_time, volume_db)
MusicManager.stop_music(fade_time)
```

`play_music` делает кроссфейд между текущим и новым треком.

### Временная музыка (стек)

Используйте стек, когда нужно временно заменить музыку:

```gdscript
MusicManager.push_music(stream, fade_time, volume_db)
# ... временная музыка ...
MusicManager.pop_music(fade_time)
```

`pop_music` восстановит предыдущий трек и позицию воспроизведения.

### Типовые обёртки с миксом

- **Ambient (уровень)**: `MusicManager.play_ambient_music(...)`
- **Меню**: `MusicManager.play_menu_music(...)`
- **Distortion**: `MusicManager.start_distortion_music(source, stream, fade, volume)`
- **Event (триггеры)**: `MusicManager.start_event_music(source, stream, fade_in, volume, fade_out)` / `stop_event_music(...)`
- **Minigame**: `MusicManager.start_minigame_music(stream, volume)` / `stop_minigame_music()`
- **Pause menu**: `MusicManager.start_pause_menu_music(stream, fade_out, volume)` / `stop_pause_menu_music(fade_in)`

Все эти методы автоматически применяют микс‑оффсеты из `MusicMixSettings`.

### Пауза всей музыки

```gdscript
MusicManager.pause_all_music(fade_time)
MusicManager.resume_all_music(fade_time)
```

### Ducking (приглушение)

Если нужно временно приглушить музыку:

```gdscript
MusicManager.duck_music(fade_time, volume_db)
MusicManager.restore_music_volume(fade_time)
```

### Музыка погони

Для погони используется отдельный режим:

```gdscript
MusicManager.set_chase_music_source(self, true, stream, volume_db, fade_out_time)
MusicManager.set_chase_music_source(self, false)
```

Музыка погони играет, пока есть хотя бы один активный источник.
При активной погоне основная музыка быстро глушится и возвращается обратно после окончания погони.

## LevelMusic (музыка уровня)

Скрипт `levels/cycles/level_music.gd` использует:

```gdscript
MusicManager.play_ambient_music(stream, fade_time, volume_db)
```

Флаг `continue_on_level_change` определяет, продолжать ли музыку при смене уровня.

## Мини‑игры и музыка

Мини‑игры управляют музыкой через `MinigameController`.
Музыка мини‑игр начинается и заканчивается резко, а базовая музыка
восстанавливается из стека при завершении мини‑игры.

## Pause‑menu

Меню паузы играет свою музыку через `start_pause_menu_music`, а остальная
музыка ставится на паузу и продолжает играть с того же места после закрытия.

## SFX (звуки)

Для звуков используйте шину **Sounds**:

```gdscript
var player := AudioStreamPlayer.new()
player.bus = "Sounds"
player.stream = some_stream
player.play()
```

`UIMessage.play_sfx(...)` также воспроизводит звук в шине **Sounds**.

## Триггеры (TriggerSetProperty)

В `TriggerSetProperty` доступны действия:

- Подменить трек (обычный `play_music`)
- Приоритетный трек: старт/стоп (event‑музыка со стеком)
- Пауза всей музыки / Возобновить музыку
- Заглушить / Восстановить (ducking)
