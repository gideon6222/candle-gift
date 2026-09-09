# Candle Gift

A native Android candle-factory runner, built in Godot 4.7.

Steer one batch of candles down a factory line. Wax lies in tubs across half the track, so
the line you steer decides which candles come out which colour. Halfway down, a wall spans
the runway and stands the whole batch upright; after it the press stamps them into shapes
and the gift station ties a bow on each. Sell the batch at the end and carry the money on.

Modelled closely on **Candle Gift** by Rollic Games, at Gideon's request.
`REFERENCE.md` is the observed record of that game — **read it before changing how anything
looks or what a station does.** The game is delisted, so that file is the primary source.

```powershell
$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

& $godot --headless --path . --import                                 # after adding files
& $godot --headless --path . --script res://test/run_tests.gd         # pure tests, ~2s
& $godot --headless --path . --script res://test/run_smoke.gd         # boots the real scene
& $godot --headless --path . --script res://test/run_probe.gd         # balance readings
& $godot --headless --path . --export-debug "Android" build/candle-gift.apk
& $godot --headless --path . --script res://scripts/check_size.gd     # size guard
& $godot --path . --resolution 460x996 --script res://scripts/shot.gd -- 26.0
& $godot --path .                                                      # open the editor
```

Every one exits non-zero on failure, which is what makes them a CI gate rather than
something to read.

`CLAUDE.md` has the toolchain paths, the invariants and the traps. Read it before writing
any game code — most of it is not obvious from the source.
