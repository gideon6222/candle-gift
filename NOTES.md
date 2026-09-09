# Notes — Candle Gift

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
