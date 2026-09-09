# Candle Gift

A native Android candle-factory runner in Godot 4.7, modelled closely on **Candle Gift** by
Rollic Games (`com.TwoPageGames.CandleGift`) at Gideon's request.

**`REFERENCE.md` is the observed record of that game — read it before changing how anything
looks or what a station does.** It has the store screenshots, two gameplay videos with the
timestamps things were read from, and the method for pulling frames out of one. The game is
delisted, so that file is the primary source. Five rebuilds of the web version got the
presentation wrong by inferring instead of looking; do not add a sixth.

**Read `C:\dev\gamedev-notes` first** — `SKILL.md` (process), `PIPELINE.md` (both stacks and
the measured limits), `CRAFT.md` (design lessons, all of which apply here), `ASSETS.md`,
`PLAYTESTS.md`. The Godot toolchain paths, the signing rules and the export traps live in
`C:\dev\godot-template\CLAUDE.md`; this file only carries what is specific to this game.

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

## Four checks, and each answers a different kind of question

```bash
scripts/check.sh          # all of it, in the order that fails fastest
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
meaning anything. Run `scripts/check.sh` before committing.

**`scripts/sheet.gd` is for looking, not for passing.** It renders twelve frames across a
level into a grid, which is how the wrong things get NOTICED; the checks above are how they
stay fixed.

## Invariants

- **`src/sim/` may not reference a Node, a Viewport, an input event or a real frame.** That
  one rule is what makes the whole-run golden possible and what let the renderer be written
  after the simulation was already tested.
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
- **`Basis.scaled()` scales the WORLD axes, not the mesh's own.** A band rotated to lie along
  world X has to be scaled `(length, radius, radius)`, not `(radius, length, radius)`.
  Getting it backwards drew the batch as a heap of overlapping boxes — it looks like a layout
  bug and is a transform one.
- **`MultiMesh.use_colors` must be set BEFORE `instance_count`.** Godot refuses to toggle it
  once a buffer exists, and the error is a runtime one that leaves the mesh silently
  untinted rather than failing the build.
- **`TorusMesh` has no arc parameter.** A "curved arm" built from one is a complete ring
  lying flat across the track. The station arms are a post and a leaning boom.
- **Cull stations against the CAMERA, not the batch.** The camera sits eleven-odd metres
  back, so a station just behind the batch is still several metres in front of the lens and
  its sign fills the bottom of the screen.
- **Nothing that affects game state may use `randf()`.** Place-keyed decisions go through
  `SimUtil.hash2` seeded on (chunk, level). The one moving obstacle takes its position from
  `distance` rather than from elapsed time — the same thing at a constant speed, and unlike
  a clock it is reproducible, so the golden holds.
- **`_ready` does not run at `add_child()`.** `main.gd` guards this with `_ensure_booted()`.
- **`visible_instance_count` is the flush**, and it has to be checked in BOTH forms of the
  batch — the flush that goes missing is the one in the form nobody tested.
- **Freeze before advancing** in any harness.

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

## Record as you go

Write lessons into `gamedev-notes` **in the same commit as the change that taught them**,
never at the end of a session. Several games run at once; a lesson recorded after this one
finishes is one the next game never got.
