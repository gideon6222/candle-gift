# Notes — Candle Gift

## Graphics pass, 2026-09-09

Judged from a **contact sheet** (`scripts/sheet.gd` + `scripts/sheet.py`), which renders
twelve frames across a whole level in one engine start and stitches them into a grid. It
found four separate faults on its first run that individually chosen screenshots had missed,
and it is now the way to look at this game:

```bash
godot --path . --resolution 460x996 --script res://scripts/sheet.gd -- 12
python scripts/sheet.py "<user data dir>/sheet" sheet.png 35.5
```

**The wax is a flat shaded quad and now reads as liquid.** `assets/shaders/wax.gdshader`:
domain-warped marbling flowing down the track, discrete dimples on a jittered grid, a ring
spreading from where the ladle's stream lands, and a fragment-computed normal map. Two things
had to be fixed before any of it was visible:

- **The pool sits at y=0.09, not 0.03.** The road stripes are boxes 0.06 tall at y=0.02, so
  their tops are at 0.05 and they were standing PROUD of the wax. It renders as pink with
  white rungs across it and reads as a transparency or z-fighting bug; it is neither.
- **The two halves are `ROAD_HALF_WIDTH * 1.04` each, not `* 0.95`.** At exactly half there
  is a white seam down the centre line. The reference has one continuous sheet with two
  colours in it.

**Stations are culled twice, on two different rules.** The pool is ground and has to outlast
the batch standing in it, so it is culled when its far edge passes the LENS. The gantry is
overhead and has to go the moment it is passed, or a three-metre sign a few metres off the
camera covers half the road - which is what one shared cull distance produced. The gantry also
moved from y=4.15 to y=6.4: at 4.15 it hung at the camera's own eye height and slid across the
middle of the frame instead of sweeping up and out of it.

**Everything instanced is toon-shaded with a fresnel ink rim** (`assets/shaders/toon.gdshader`)
rather than an inverted hull. The hull is the normal way to do this and **it does not work on a
Godot MultiMesh** - it draws over the object. That was measured, not assumed: with the hull
shrunk six centimetres INSIDE the candle it still covered it, in every combination of
`CULL_FRONT` / `CULL_DISABLED`, `next_pass` / sibling instance, depth writing on and off, and
both render priorities. It works fine on a `MeshInstance3D`, which is what makes it look like
it should work here.

The rim matters more than it sounds: a cream candle lying on this white runway had no edge at
all and rendered as a grey smear that could not be told from a shadow.

`sun.light_energy` dropped 1.25 -> 1.0 and the toon `light()` is deliberately dim
(`0.10 + 0.42 * d`), because the sky HDRI is already a strong ambient and a full diffuse term
on top of it blew every pale surface out to pure white.

### Still wrong, in the order the sheet shows them

1. **Obstacles are placeholders.** The roller is a giant gold cylinder that reads as a
   baguette; the spikes are plain cones. `REFERENCE.md` says jagged crystal shards with a
   curved silhouette, brighter coral at the tips over a deeper red-orange base.
2. **The HUD is plain white text.** It should be gold rounded pills with a dark outline and
   white bold text, the money pill carrying a small green banknote icon. `Fredoka-Bold.ttf`
   and `Fredoka-SemiBold.ttf` are in `assets/font/` and are not yet used by anything.
3. **The sky is flat cyan.** The reference is a gradient, deeper at the top.
4. **Money and loose candles** are a green bar and gold sticks. They want the dark green price
   tag with a white punched hole, and white wicks on the candles.
5. **No home screen, shop, end-of-run ruler, reward screen, sound or saving.**



Per-game truth. Where this and the shared notes disagree, **this file wins.**

| Topic | Status |
|---|---|
| Stack | Godot 4.7.2, copied from `C:\dev\godot-template`. Pure sim core, headless tests, whole-run golden, APK size guard, CI. |
| Source | `src/sim/` is the game and has no renderer in it. `src/game/main.gd` draws it. |
| Deploy | Push to `main`; CI gates and puts a signed APK on a Release. |
| Reference | `REFERENCE.md`, observed from the store screenshots and two walkthrough videos. |

## Where this came from, and what was deliberately left behind

The web version lived at `Desktop\ClaudeCode\Captain_Run` and reached v7.0.0. It began life
as a viking crowd-runner called Captain Run, was reshaped into a candle game, and kept
inheriting the earlier game's shape — its HUD, its upgrade sheet, its obstacle set. Gideon
asked for a rewrite that went only off the research.

**Nothing was carried over except `REFERENCE.md`.** That file is research, not code: eight
store screenshots, two walkthrough videos with the timestamps each finding was read from,
and the method for pulling frames out of a video. Everything else was written fresh against
it.

## The two sections

A level runs flat until the ROTATE wall at chunk 17, then standing. That is the single
biggest structural fact in the game and it took the web build five versions to find, because
`ROTATE` was assumed to mean "turn the batch end for end". It does not: it stands the batch
**up**, flat slab at 15.5s in the walkthrough and a standing rank at 15.8s with the plate
still visible behind it at 16.1s.

Everything follows from it. The press cannot stamp a candle lying on its side and a bow
cannot be seen on one, so every station that needs a standing candle lives after the wall,
and every station before it is wax. `test_the_stations_before_the_wall_are_all_wax` is the
guard.

## Balance, as measured

`run_probe.gd`, six levels, value normalised by each level's own price scale:

| policy | L1 | L2 | L3 | L4 | L5 | L6 | mean | stars at PAR 10000 |
|---|---|---|---|---|---|---|---|---|
| idle   | 2314 | 1129 | 2105 | 3362 | 1859 |  819 |  1931 | 0 |
| dodge  | 3271 |  582 | 3098 | 9792 | 2525 |12067 |  5223 | 1 |
| gather | 3575 | 1660 | 3416 | 4859 | 2681 | 5390 |  3597 | 1 |
| weave  |13808 | 2646 |19596 |28100 |17195 |28293 | 18273 | 3 |

Weaving is worth **9.5x idling**, which is the number that says the pools are the game.

Two things worth keeping in mind before touching these:

- **The mean is the number to calibrate on.** A single level swings a policy by a factor of
  four on layout luck alone — dodge scores 582 on level two and 12067 on level six.
- **Dodge and gather are close, and that is honest.** Dodging protects a batch it never
  builds; gathering builds one it never improves. They fail for different reasons and land
  in the same band.

## What the first pass got wrong, and what fixed it

Recorded because each is cheap to reintroduce.

1. **`Trail.layout` called `sample_back` per candle**, which is quadratic. Thirty candles
   each walking ninety trail samples is 2,700 steps a frame — invisible in a game running one
   level and ruinous in a suite running twenty of them. The pure tests went from ~2s to over
   five minutes, which reads as a hang. One backward walk emits the whole batch.
2. **`Basis.scaled()` scales world axes, not the mesh's own.** The bands were scaled as if
   the cylinder were still upright after being rotated flat, and the batch drew as a heap of
   overlapping boxes. It looks like a layout bug and is a transform one.
3. **`MultiMesh.use_colors` after `instance_count`** is refused at runtime with "Instance
   count must be 0 to toggle whether colors are used" — and the mesh is silently untinted
   rather than the build failing.
4. **`TorusMesh` has no arc parameter**, so the "curved lamp-post arm" drew as a complete
   ring lying flat across the track.
5. **Stations culled against the batch** are still in front of the lens, because the camera
   sits eleven metres further back. A passed station's sign filled the bottom of the screen.
6. **A flat obstacle cost against a batch of one** ends the run before the player has touched
   anything. `cap_take` caps it at half of what is held.
7. **Hazard rates that did not scale** made every policy finish level one with one or two
   candles, having collected eight and lost eight — a treadmill rather than scarcity.

## Known gaps / next

1. **No shop, no home screen, no end-of-run screen yet.** The level loop runs and rolls
   straight into the next one after an interlude. The web build's shape for these is in its
   `REFERENCE.md` section "The screens" — a home screen with two boost cards and a SHOP
   button, a money ruler with your own best marked on it, and a plain continue.
2. **No sound.** Everything on the web build was synthesised at runtime; Godot has
   `AudioStreamGenerator` for the same trick, and `ASSETS.md` says audio is the one category
   worth importing now that there is no download-size limit.
3. **The gear opens nothing.** It restarts the level, which is at least an escape from a run
   that has gone wrong. Settings, the changelog and the build stamp belong behind it.
4. **No save.** `user://` on Godot; level and money should persist.
5. **The wax does not flow and does not ripple.** The web build learned that a liquid is
   made of motion and answers rather than of texture — a scrolling surface and a ring
   wherever something enters it. Neither is here yet.
6. **Nobody has played it with a thumb.** Everything above is verified through the headless
   seam and screenshots at the phone's aspect ratio.
