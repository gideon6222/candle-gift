# Candle Gift

A native Android candle-factory runner in Godot 4.7, modelled closely on **Candle Gift** by
Rollic Games (`com.TwoPageGames.CandleGift`) at Gideon's request.

**`REFERENCE.md` is the observed record of that game — read it before changing how anything
looks or what a station does.** It has the store screenshots, two gameplay videos with the
timestamps things were read from, and the method for pulling frames out of one. The game is
delisted, so that file is the primary source. Five rebuilds of the web version got the
presentation wrong by inferring instead of looking; do not add a sixth.

@../gamedev-notes/INDEX.md

The shared rules, the Godot traps, the toolchain paths, the export and signing rules and
the process are in `C:\dev\gamedev-notes` (`INDEX.md` above, then `GODOT.md`, `CRAFT.md`,
`TESTING.md`, `ASSETS.md`, `POLISH.md`). **This file carries only what is specific to this
game.** `NOTES.md` has the decisions and measurements; `PLAN.md` the milestones;
`C:\dev\gamedev-notes\playtests\candle-gift.md` his words about it.

---

## Where this came from

The web version of this game lived at `Desktop\ClaudeCode\Captain_Run` and went through
seven versions. **This is a rewrite, not a port**: nothing was carried over except
`REFERENCE.md`, which is research rather than code. Gideon asked for exactly that — the
web build had started life as a viking crowd-runner and kept inheriting its shape.

## Commands

See `README.md`. `--import` after adding files, `run_tests.gd` for the pure suite,
`run_smoke.gd` for the real scene, `run_probe.gd` for balance, `shot.gd` for a screenshot at
the PHONE's aspect ratio.

## Files

| File | What it is |
|---|---|
| `src/sim/sim.gd` | **The whole game, with no renderer in it.** Two sections, stations, obstacles, pickups |
| `src/sim/tuning.gd` | Every number, plus the derived arithmetic |
| `src/sim/candle.gd` | ONE candle's recipe, and the geometry and value derived from it |
| `src/sim/wax.gd` | The palette, the moulds and the wrappings |
| `src/sim/trail.gd` | The recorded path and the layout that lags behind it |
| `src/sim/stations.gd` | What each station kind is, and where a level puts them |
| `src/game/main.gd` | The shell: reads `Sim`, draws it, feeds it input. Decides nothing |
| `test/policies.gd` | Scripted players. **The definition of "playing well"** |
| `REFERENCE.md` | **What the real game actually does**, observed |
| `NOTES.md` | Decisions specific to this game, the balance table, and what to do next |

## The two axes

Everything in the game is one of these:

- **How many candles** — loose candles on the runway add one each; obstacles knock them off
  the back of the batch.
- **What each one is worth** — the pools, and **every candle carries its own recipe**.

## Per-candle recipes are the game

Wax is a **pool on the ground**, not a gate. Which candles get which colour depends on where
each one was as the batch snaked over it — and because the batch trails along the leader's
recorded path, **the player's line is the decision.** The reference's own strategy guide says
it outright: *"if there are two pools of wax side by side, you should swipe left and right
quickly to try and dunk all of your candles in both of the pools."*

Treating the batch as one shared recipe deletes that entire skill. Measured on the web build,
it produced an **identical** per-candle value across four scripted play styles.

`weaving the pools beats only collecting` is the standing guard on it.

## A RUN IS FOUR PHASES, and `_set_phase` is the only thing that changes them

`HOME -> RUN -> RULER -> REWARD -> HOME`, and every screen in the game is one of them.

**HOME is not a menu.** The reference has nothing that stops the world: between runs the
player sits on the runway with the level already built behind the cards, and the first swipe
starts it. So HOME is the game with `sim.advance` not being called - `_sync()` still runs, and
what you are looking at is the level you are about to play.

**`_set_phase()` is the only writer.** Assigning `_phase` and calling `_show_screens()` next to
it worked in four places out of five; `freeze()` set the phase to RUN and left the home screen
drawn over the entire game. `_show_screens()` recomputes every screen's visibility from the
phase, so a screen cannot be left up by a transition nobody thought about.

**`freeze()` starts in RUN**, because a harness plays rather than sitting on the home screen
waiting for a swipe. It is the same simulation either way - HOME differs only in not calling
`advance` - so this is a starting phase, not a test-only path.

## `sim.cash` is THIS RUN's notes. The bank is `_bank`, and it never enters the simulation

`appraise()` is what the run was worth: the batch, scaled, plus the notes picked up on this
runway. `restart` zeroes those. What the player owns is `_bank` in `main.gd`, written to the
save, and spent by the shop and the boost cards.

Seeding the bank into `sim.cash` made every run appraise the player's whole balance as if they
had just earned it, and the reward screen banked it again - 5,000 became 141,699 in three runs
of the same level. It also made the entire shop ladder affordable inside five runs, which is
how it was found.

**The obvious test does not catch this.** "The bank went up by what the screen said" holds
either way, because both sides inflate together. The guard is
`test_a_runs_value_does_not_depend_on_the_bank`: play the same level twice with different
amounts of money and demand the same answer.

## Money is in the reference's units

`VALUE_SCALE = 0.03`, applied once in `appraise`. A level-one weaving run pays about 472; the
reference rewards about 540 for a comparable run. Before it, ours paid 18,273 - and the only
two shop prices ever observed are $1,000 and $4,000, which against 18,273 a run are not prices
at all. Everything downstream (PAR, the ruler, the money pill, the ladder) is in those units,
so they stay comparable to the footage.

## Anything that restarts a level owes it the save

`Sim.restart()` zeroes `cash`: as far as the simulation is concerned that is per-run state.
Progress lives in `save.gd` and is pushed back in by `_apply_save_to_sim()`. Buying a boost
restarts the level so the extra candle is actually in the batch - and without the reapply it
spent 500 and then wiped every other coin the player had on the way out.

## Preferences are not progress

`save.gd` owns `user://candlegift.v1.json`. A settings file, when it arrives, gets its own.
A pause screen offers to erase your progress next to switches that control sound, and that
promise only holds if the two are separate things.

`Save.wipe()` sets a **one-way latch** that makes `store()` a no-op for the rest of the
process. The game saves when it loses focus, and "clear my progress" is followed immediately by
exactly that, so without the latch the erased state is written straight back and the button
appears to do nothing.

## Four checks, and each answers a different kind of question

```bash
scripts\check.ps1        # all of it, in the order that fails fastest - the gate
scripts/check.sh          # the same steps under bash, for a Git Bash shell
```

| | Runs | Answers |
|---|---|---|
| `test/run_tests.gd` | headless | is the simulation right |
| `test/run_smoke.gd` | headless | is the scene built, and is everything WHERE it should be |
| `test/run_visual.gd` | needs a GPU | is the picture legible |
| `scripts/check_size.gd` | headless | did the APK move |

**Geometry goes in `run_smoke.gd`, not in `run_visual.gd`.** This was learned the
expensive way. Two visual bugs - a wax pool rendering striped, and a station sign hung at the
camera's eye height - were both attacked first as pixel statistics, and three separate metrics
were written and thrown away because none of them separated a broken build from a healthy one
by more than a few percent. Both are geometry, and geometry is a NUMBER in the model: the
pool's y against the stripe tops, the gantry's distance from the lens. In the model they are
exact, and the failure message says which pool and how far off.

What frame statistics are good for is the whole picture going wrong at once - which the model
cannot see at all, and which is exactly how the build where every instanced object rendered as
a solid black silhouette got through with every assertion green.

**Every threshold in `run_visual.gd` is measured and then checked against a deliberately
broken build.** `-- --report` prints the metrics and asserts nothing. A guard that does not
move when the bug is present is worse than no guard: it is a green light nobody has any reason
to doubt.

**`run_visual.gd` is a LOCAL gate and is deliberately not in CI.** CI has no GPU, and the
software renderer available there is a different one - thresholds derived on Vulkan would have
to be re-derived on llvmpipe, and two sets of numbers for one check is how a check stops
meaning anything. Run `scripts\check.ps1` before committing (or `scripts/check.sh`
from Git Bash - the same steps).

**`scripts/sheet.gd` is for looking, not for passing.** It renders twelve frames across a
level into a grid, which is how the wrong things get NOTICED; the checks above are how they
stay fixed.

## Invariants

Shared invariants (pure sim, no `randf()` in state, the hash, `_ensure_booted`, `looking_at`, the flush, freeze-before-advance, anchored HUD, `FLOAT_EPS`, headless MultiMesh colours, `global_transform`, Dictionary Variants, `use_colors`, `Basis.scaled`, `TorusMesh`, culling against the camera) are in `GODOT.md` and are not repeated here.

- **A LEVEL IS TWO SECTIONS, and the ROTATE wall divides them.** Before it the candles lie
  flat and the runway is wax; the wall spans the whole track so it is crossed exactly once;
  after it they stand in a row and the runway is the machines that need them standing. A
  press cannot stamp a candle lying on its side and a bow cannot be seen on one — so
  `test_the_stations_before_the_wall_are_all_wax` fails if a slot is put on the wrong side.
- **The batch starts at ONE**, and `cap_take` stops an obstacle taking more than half of it.
  A flat cost of three against a batch of one is the end of a run before the player has
  touched anything.
- **Spacing does not change between the two forms.** The simulation lays candles out at
  `TRAIL_GAP` to decide what a pool dips and what an obstacle clips; if the renderer draws
  them anywhere else, what you see is not what collides.
- **`Trail.layout` is ONE backward walk for the whole batch.** Calling `sample_back` per
  candle is the obvious way to write it and it is quadratic — the pure suite went from about
  two seconds to over five minutes, which reads as a hang rather than as slow code.
## Numbers that are measured, not chosen

- **`PAR = 10000`**, from the **mean over six levels** with the policies in
  `test/policies.gd`. One procedural level swings a policy enormously on layout luck, so a
  constant calibrated against level one is calibrated against nothing. The table is in
  `NOTES.md`; `run_probe.gd` prints it.
- **The hazard rates rise with the level and start low.** At a flat 0.40/0.30/0.28 every
  policy ended level one with one or two candles, having collected eight and lost eight — a
  batch that cannot outgrow the runway is not scarce, it is a treadmill.
- **`CASH_VALUE = 45`.** Money used to be most of what a run was worth, which made the batch
  — the thing the whole game is about building — a rounding error next to green tags.

## Shared rules and recording

Everything general lives in `C:\dev\gamedev-notes`: the invariants every game keeps and the
engine traps in `GODOT.md`, design in `CRAFT.md`, the ship gate in `POLISH.md`. Record a
lesson the moment it is learned with `/record-lesson` (it writes to the notes' `inbox/`),
and his words with `/record-lesson playtest candle-gift`. Never edit the notes' topic files from
a build session.
