# Scale Viewer for REAPER

Dockable ReaImGui window showing a guitar fretboard with the notes of a chosen scale.

## Requirements
- REAPER with ReaPack and ReaImGui 0.10+ (Extensions → ReaPack → Browse packages → "ReaImGui").

## Run
1. Actions → Show action list → New action → Load ReaScript… → pick `Scale_Viewer.lua` from this repo.
2. Run the action. Optionally bind it to a toolbar button or shortcut.
3. To dock: drag the window by its title bar onto a REAPER docker, or use the title bar's right-click menu.

`theory.lua` must stay next to `Scale_Viewer.lua`.

## Tests
Music theory lives in `theory.lua` and is tested with plain Lua 5.4:

```bash
lua tests/theory_test.lua
```
