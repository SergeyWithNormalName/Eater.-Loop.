# macOS DMG Export Fix (Godot 4.6)

## Problem

On newer macOS versions, Godot's built-in DMG export can fail with:

- `Создание DMG: Не удалось выполнить hdiutil create`
- `hdiutil: create failed - Нет подключенных файловых систем`

Root cause: Godot calls `hdiutil create ... -fs HFS+ ...`, but that filesystem mode is no longer usable on this macOS.

## Project workaround

This repository contains a local `hdiutil` wrapper:

- `tools/macos_dmg_fix/hdiutil`

For `hdiutil create`, it rewrites `-fs HFS+` to `-fs APFS`.

## How to use

1. Launch Godot via:
   - `tools/macos_dmg_fix/run_godot_with_dmg_fix.sh`
2. Export macOS preset as usual from the editor.

Or export directly from terminal:

- `tools/macos_dmg_fix/export_macos_dmg.sh`
- `tools/macos_dmg_fix/export_macos_dmg.sh /absolute/path/MyBuild.dmg`
