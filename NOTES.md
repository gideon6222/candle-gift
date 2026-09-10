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

### The screens, 2026-09-09

**The HUD pills are gold**, with a dark line round them and white Fredoka text, and the money
pill carries a small green banknote drawn in `_draw_note` rather than imported - it is thirty
pixels wide on the phone. Each pill is a `PanelContainer` so it sizes itself to the text; a
fixed-width pill clips `1,250 $` the first time the player has a good run.

The smoke test that guards HUD anchoring now **walks up from the label to whatever is
anchored** instead of checking the label itself. Wrapping the label in a panel made its own
anchors meaningless and turned the check red for a change that was entirely correct - it was
asserting the shape of the scene rather than the property the rule is about.

**The sky is a gradient**, deeper at the top, and the CC0 HDRI is gone. It was kept so glossy
surfaces had something to reflect, under "take the lighting, leave the picture" - but an
Environment has one sky, and a gradient of our own colours has no join to show, so it can be
the background and the ambient at once. The horizon end never goes lighter than the flat cyan
it replaces, or the white runway dissolves into it at about twenty metres.

**Ambient is a neutral COLOUR while the background and reflections come from the sky.** Taking
ambient from the sky as well turned every station sign from magenta to navy: a sign faces the
camera with the sun behind it, so its face is lit by ambient alone, and blue ambient times a
magenta albedo has almost no red left. Anything warm and out of direct sun goes dark and
slightly wrong, which is a hard thing to trace back to the light.

### The size budget: the 2 MB gap was the HDRI, not the toolchain

Worth recording because the wrong explanation was reached first. CI's build 1 came out at
29.10 MB against a 26.98 MB budget - +7.9% against a 10% tolerance - and the natural reading
was that CI and this machine build differently. They do not. Build 1 was made from the commit
that still had the 1.4 MB HDRI in it; build 2, with it gone, is 27.10 MB against a local 27.03.
A 0.3% difference, which is the toolchain.

**A number from before a change is not a baseline for after it.** The comparison that mattered
was CI-to-CI, and there was only one CI build to compare at the time.

### The testing pass, 2026-09-09

Three candidate pixel metrics were written and thrown away, which is the finding worth keeping:

| Metric | Good build | Broken build | Verdict |
|---|---|---|---|
| colour changes across a row | 45 | 49 (striped pool) | useless |
| saturated runs across five rows | 7 | 8 (striped pool) | useless |
| fraction of upper frame still sky | 0.869 | 0.826 (sign at eye height) | too weak |
| **fraction of lower frame near-black** | **0.028** | **0.196** (everything inked) | **kept** |

The two bugs that resisted are both GEOMETRY, and they moved to `run_smoke.gd` where the answer
is a number: `_check_the_pool_clears_the_stripes` compares the pool's y against the stripe
boxes' tops, and `_check_no_gantry_is_left_behind` tracks the nearest visible gantry to the
LENS across twelve seconds of play. Both were verified by reintroducing the original bug and
watching them fail with a message that names the number.

Also learned: **five sampled seconds is not a sweep.** The first version of `run_visual.gd`
checked five chosen moments and missed the very bug it was written for, because a station sign
only fills the frame for about a second after the batch passes under it. It now samples every
1.5 s across the level and judges the worst frame. Transient is exactly what a chosen-moment
check cannot see, and transient is most of what is wrong with a runner.

And: **`_check_no_gantry_is_left_behind` was wrong on its first draft** in an instructive way.
Written as "no gantry behind the batch", it failed on a deliberate one-metre grace that stops
the gantry popping out as you cross it. A gantry a metre behind the batch is eleven metres from
the camera and harmless; the rule is about distance from the LENS. Stating a guard in terms of
the thing it is really about is what stops it failing on correct changes.

### The screens, and saving, 2026-09-09

`HOME -> RUN -> RULER -> REWARD -> HOME`. The home screen is on the runway with the level
already built behind it; the ruler is absolute money with your own best marked in yellow, which
the batch climbs on a timer; the reward card is the plain amount and a TAKE button.

**No multiplier fan.** The reference's is a rewarded-video wheel and this game has no ads - a
spinner that always lands on x1 is a worse screen than no spinner. Gideon asked for the plain
amount and a continue button, and that is what it is.

The whole flow is driven end to end by `run_smoke.gd` through real pointer events: play a level
out, assert the ruler is up and the simulation is NOT running under it, wait for the handover,
press TAKE, assert the money is banked and the next level started, assert the home screen does
not advance the world, then swipe and assert it does.

Two bugs found by writing that, both of which would have shipped:

- **Buying a boost wiped the player's money.** The boost restarts the level so the extra candle
  is really in the batch, and `Sim.restart()` zeroes cash.
- **`freeze()` left the home screen drawn over the game.** It set the phase to RUN without
  refreshing the screens. Found by `run_visual.gd`, not by any model assertion - every number
  was right and the picture was not - and fixed structurally by making `_set_phase()` the only
  writer.

### The shop, 2026-09-09

**The shop sells SHOPS**, which is the reference's whole meta-game: there is no upgrade sheet
anywhere in six levels of footage. `shops.gd` is a seven-rung ladder. The first four names and
the two prices marked in the file are the reference's; the last three - DEPARTMENT STORE,
ATELIER, FLAGSHIP STORE - are ours, because the footage stops at level six and stopping there
would leave the third mould and the third wrap unreachable. `test_every_shop_grants_something_reachable`
asserts the top of the ladder reaches the top of the content.

**Stats are derived from what is owned, never stored beside it.** `Shops.stats_for(owned)` is
the only read. A field kept next to the list of shops is a second source of truth, and the two
drift the first time a rung is inserted into the middle of the ladder - which is exactly when
nobody is looking.

**A shop can only be bought if it is the next rung.** Without that, one lucky run buys the
FLAGSHIP STORE and skips everything under it: the player owns the best wrap in the game while
the press is still stamping PLAIN.

### A Godot ScrollContainer does not scroll from a finger

Measured, because it is not written anywhere obvious. Pushing each kind of event at a
`ScrollContainer` with content taller than its view:

| Event | `scroll_vertical` |
|---|---|
| mouse wheel | 50 |
| `InputEventPanGesture` | 400 |
| `InputEventScreenDrag` | **0** |

`emulate_mouse_from_touch` does not save it either, because a mouse *drag* is not a wheel. So
the shop list would simply not have moved on the phone, and nothing about it looks wrong in the
editor or in a screenshot. `_on_shop_drag` translates the drag into `scroll_vertical` by hand.

The rows also have to be `MOUSE_FILTER_IGNORE`. A `Control` defaults to STOP, containers
included, so every row would swallow the gesture and the list would move only when the finger
happened to land in a gap between two of them.

### Sound and the pause panel, 2026-09-09

**Every sound is synthesised at boot; there are no audio files.** `sfx.gd` builds eight
`AudioStreamWAV`s from sine waves and a deterministic hash, plus a sixteen-second looping music
bed. Two reasons, and the second is the real one: a folder of .wav files for eight short blips
is a folder to keep in step with the code that names them - and a rename that misses one is
silence, which nothing reports. A sound that is a FUNCTION can take arguments, so `dip` is
pitched by which layer the candle is on and a batch weaving through four pools plays a rising
figure rather than four identical clicks.

Eight voices, round-robin. One player restarted on every event cuts its own tail off, and a
whole slab crossing a pool fires one dip per candle in the same frame - which should be a chord,
not the last one.

**The gear opens a pause panel** instead of restarting the level. Restarting was somewhere for
the gear to live rather than a decision, and a destructive one to hand a player who tapped it by
accident mid-run. The panel keeps two promises about two different files: SOUND and MUSIC live
in `settings.gd`, CLEAR SAVE DATA erases `save.gd`, and each leaves the other alone.

**Clearing takes two taps, and anything else on the panel disarms it.** One tap next to two
switches is a run of progress gone to a mis-tap with nothing behind it.

### An engine error is a failure, even when every assertion passes

`scripts/check.sh` now fails on any `ERROR:` line. The suite printed "Playback can only happen
when a node is inside the scene tree" and reported itself green in the same breath - `set_music`
was called during boot, before the node was in the tree. An error nobody has to act on is an
error everyone learns to scroll past, and the next one under it is the real one.

### A test must not depend on what the case before it left on disk

`the gear pauses` asserted that sound starts on, and it was false - because an earlier case in
the same suite had written a settings file with the sound off, and the scene had read it at
boot. Wiping the file was not enough; the scene was still holding the old value. A check that
depends on ordering fails in isolation or passes in the wrong order, and either way it is not
testing what it says it is.

### The economy, measured, 2026-09-09

Adding the shop meant asking a question nothing had ever asked: **is the ladder priced
sensibly?** `run_probe.gd` grew a table for it, and the first answer was that every shop was
affordable inside five runs - the first rung cost a twentieth of one. Chasing that found two
real bugs and one structural one.

**THE BANK WAS COUNTED AS RUN EARNINGS AND PAID BACK INTO ITSELF.** `appraise()` adds `cash`,
and `cash` was being seeded from the save, so a run appraised the player's whole balance as if
they had just earned it - and the reward screen then banked that. Measured, playing the same
level three times with 5,000 in the bank:

| run | bank before | appraised | bank after |
|---|---|---|---|
| 1 | 5,000 | 18,808 | 24,528 |
| 2 | 24,528 | 38,337 | 63,585 |
| 3 | 63,585 | 77,394 | 141,699 |

`sim.cash` is now the notes picked up on the current runway and nothing else. The bank is
`_bank` in `main.gd` and never enters the simulation.

**The obvious assertion does not catch it.** "The bank went up by the amount the reward screen
said" is true either way, because both sides inflate together: the screen says R + bank and the
bank goes up by R + bank. `test_a_runs_value_does_not_depend_on_the_bank` plays the same level
twice with different amounts of money and demands the same answer, which is the only shape that
separates them. Verified by reintroducing the bug.

**MONEY IS NOW IN THE REFERENCE'S UNITS.** A level-one weaving run appraised at 18,273 where
the reference rewards about 540 for a comparable run - thirty-four times out. That is not
cosmetic: the only two shop prices ever observed are $1,000 and $4,000, and against 18,273 a
run they are not prices at all. `VALUE_SCALE = 0.03` is one constant applied once in
`appraise`, so PAR, the ruler, the pill and the ladder all move together. A level-one weaving
run now pays **472**. `CASH_VALUE` went 45 -> 5, because the reference's price tags say `5 $`.

**LEVEL_SCALE 1.55 was hyperinflationary.** A run's value multiplied EIGHTY TIMES over ten
levels, so no fixed price list could mean anything: even after repricing, all seven shops were
bought by level nine. At 1.20 it is 6.2x over ten levels and 38x over twenty - still a strong
sense of getting richer, slow enough that a price list can span the game. It touches no
recorded number, because `norm` divides by `scale_for(level)` and the golden is level one.

**PAR = 450**, re-derived from the new means over six levels: idle 100, dodge 194, gather 172,
weave 600, landing on 0 / 1 / 1 / 3 stars. Weaving is worth **6.0x** idling.

### The ladder, measured by playing it

The first version of this table divided each price by the mean run value over levels one to
six and reported that the last shop took 75 runs. That number is meaningless - a run's value
scales with the LEVEL, so a player on the seventh rung earns many times the mean of the first
six. **Dividing a late price by early income measures a player who never got better.** It now
plays the progression: weave every level, bank it, buy whatever is affordable.

| Shop | Price | Reached at level |
|---|---|---|
| ONLINE SHOP | 1,000 *(observed)* | 3 |
| BOUTIQUE | 2,500 | 5 |
| SCENT SHOP | 4,000 *(observed)* | 6 |
| LUXURY SHOP | 12,000 | 9 |
| DEPARTMENT STORE | 38,000 | 12 |
| ATELIER | 120,000 | 15 |
| FLAGSHIP STORE | 420,000 | 20 |

Owning everything is worth **3.0x** a fresh install, run for run.

### The phone build, 2026-09-09

**STEERING WAS INVERTED.** World +x is on screen LEFT - measured, x=+2 projects to screen 182
and x=-2 to 898 in a 1080-wide frame - so the drag handler must subtract, and it added. The
last game on these notes shipped this bug for its entire life, and the reason is always the
same: every test drives `steer_to()` in WORLD coordinates, where the sign is right either way.
`dragging right moves the batch right` projects the batch through the camera with
`unproject_position` and compares PIXELS.

**A DIP IS A COAT, NOT A STRIPE.** The recipe used to cut the candle into equal slices and give
each slice its own radius, which builds a stepped cone - "little blocks" on the phone, which is
exactly what it was. Each layer is now a sleeve from the BASE up to its own height, evenly
spaced, at a slightly larger radius: the newest wax is widest and lowest, every earlier layer
stays visible as a ring above it, and the silhouette is a candle. `RADIUS_PER_LAYER` went
0.045 -> 0.012, because eight coats at the old step doubled the candle's radius.

Not the onion model, which was tried and rejected on the sibling build: concentric full-height
shells hide every layer inside the outermost, and five dips render as a plain cylinder.

**A FRESNEL RIM NEEDS SMOOTH NORMALS.** `SurfaceTool.generate_normals()` on unindexed geometry
gives every facet one flat normal, so a fresnel term is CONSTANT across each facet - it cannot
draw an edge, it darkens whole panels. A standing candle came out with a black crescent smeared
up one side that read as a shadow, and no amount of tuning `ink_width` fixed it because the
problem was not the width. `st.index()` before `generate_normals()` welds the shared vertices,
the normal sweeps smoothly round the candle, and the same shader draws a line.

Also: the ink is suppressed on faces pointing along world Y. A cap is only ever seen edge-on,
so the fresnel inked the whole disc under every upright candle.

### The crash: not reproduced, surface reduced, and the next one will report itself

Measured on this machine with `scripts/soak.gd` - real frames, real rendering, 150 s across four
levels:

| | |
|---|---|
| crash | none |
| worst MultiMesh pool | `bands` 153 / 240 |
| object count | flat, ~2,150 |
| static memory | flat, ~72 MB |
| video memory | flat, ~54 MB |
| wax shader | 0.26 ms of a 1.60 ms frame at 1080x2340, vsync off |

`Candle.dip` caps at `MAX_LAYERS` and every instance write is bounds-checked, so it is not an
overflow. No device is attached here, so there is no logcat.

**Materials are cached now.** `_dress_rig` built three fresh `StandardMaterial3D`s per visible
station half per frame - about 360 new RIDs a second. Nothing accumulates on a desktop, but it
is churn a mobile driver absorbs sixty times a second for no reason, and it is the strongest
candidate found. `_stream_mat` has its own cache because it MUTATES what it builds, and `_mat`
now hands out shared materials.

**`blackbox.gd` writes a marker at boot and clears it on a clean exit.** If the marker survives,
the next launch shows the tail of `user://logs/godot.log` on screen to be screenshotted. With no
cable, that is the only channel back from the phone.

### Still to build

The SHOP button says "COMING SOON". The shop sells SHOPS - Online, Scent, Boutique, Luxury -
and `sim` already carries `earn_level`, `press_level`, `wrap_level` and `has_scent` for them to
buy, so the model is ready and only the screen is missing. After that: sound, and a gear that
opens something other than a level restart.

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
