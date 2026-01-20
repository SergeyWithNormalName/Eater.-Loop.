# Система музыки и звука

Этот документ описывает, как в проекте устроено управление музыкой и звуками.

## Шины (Audio Buses)

В проекте используются две ключевые шины:

- **Music** — вся музыка (фон, мини‑игры, погони).
- **Sounds** — все SFX (шаги, взаимодействия, UI‑звуки).

Создание/проверка шин выполняется в `SettingsManager` при старте игры.

## MusicManager (autoload)

`MusicManager` — единая точка управления фоновой музыкой.

### Базовое воспроизведение

```gdscript
MusicManager.play_music(stream, fade_time, volume_db)
MusicManager.stop_music(fade_time)
```

`play_music` сам делает кроссфейд между текущим и новым треком.

### Временная музыка (стек)

Используйте стек, когда нужно временно заменить музыку (мини‑игры, меню):

```gdscript
MusicManager.push_music(stream, fade_time, volume_db)
# ... временная музыка ...
MusicManager.pop_music(fade_time)
```

Вызов `pop_music` восстановит предыдущий трек и позицию воспроизведения.

### Ducking (приглушение)

Если нужно временно приглушить музыку:

```gdscript
MusicManager.duck_music(fade_time, volume_db)
MusicManager.restore_music_volume(fade_time)
```

### Музыка погони

Для погони используется отдельный режим:

```gdscript
MusicManager.configure_runner_music(stream, volume_db, fade_time)
MusicManager.set_runner_music_active(self, true)
MusicManager.set_runner_music_active(self, false)
```

Музыка погони играет, пока есть хотя бы один активный источник.

## SFX (звуки)

Для звуков используйте шину **Sounds**:

```gdscript
var player := AudioStreamPlayer.new()
player.bus = "Sounds"
player.stream = some_stream
player.play()
```

`UIMessage.play_sfx(...)` также воспроизводит звук в шине **Sounds**.

## Мини‑игры и музыка

Мини‑игры управляют музыкой через `MinigameController`, который использует `MusicManager.push_music(...)` и `pop_music(...)`. Это гарантирует, что после мини‑игры корректно восстановится предыдущий трек.
