# Plan — Candle Gift

## What now

The first unticked box in the milestone list below. Everything above it is shipped and
verified; everything below it is the distance between this game and what he actually asked
for.

---

## Round five is on its ninth of eleven boxes

Shipped 2026-09-10: shadows and fog, the camera framing the whole batch, floating value text,
particle bursts, the camera kick, the numbered price tags, the podium, the Android back
button, the version-drift test, and filming. Left: 1.4 (wax sheen) and 3.3 (shops bought in
the track), both described where they sit below.

## The standing goal, in his words

From 2026-09-07, and re-stated on 2026-09-10 as the thing to work toward rather than the
defect list:

> "make the visuals, mechanics, and gameplay look more like this? but **an upgraded version
> with similar art style and better graphics**. also changes the menus and upgrades to match.
> ... We will continue to make changes to **make it better than the one she remembers** but I
> want it to start out very similar."

So there are two bars, and only the first has ever been worked:

1. **Resemble the reference.** `REFERENCE.md` is the observed record. Mostly met — the
   sections, the stations, the per-candle recipes, the shop ladder, the screens.
2. **Be better than it.** Not started. Nothing in this game does anything the reference does
   not, and several things it does are cheaper: there are no shadows, no atmosphere, no
   world-space feedback and no impact on a hit.

Round five (2026-09-10) is the second bar.

---

## Round five — upgrade every aspect

Judged from the contact sheet of level one at 460x996 and from grepping for the thing rather
than assuming it. Each box names what he can see or do when it is ticked.

### Phase 1 — the picture

The single largest gap to "better graphics", and it is not subtle: **the sun has never had
`shadow_enabled` set**, so nothing in the game casts a shadow and every object floats on a
flat white road. There is no fog either, so the runway ends at a hard vanishing point.

- [x] **1.1 Everything sits on the ground.** Shadows on, tuned for a mobile GPU, with the
      batch, the obstacles, the stations and the loose candles all grounded. Measured cost in
      ms before and after; a shadow budget that fails the size/perf guard is not shipped.
- [x] **1.2 The runway has depth.** Distance fog whose colour is the sky's horizon end, so the
      road fades rather than terminating, and the skyline pushed back and hazed so the towers
      read as scenery rather than as props crowding the rails.
- [x] **1.3 The batch is never clipped by the bottom of the frame.** In sheet cells 6-8 the
      front of the batch is cut off by the screen edge. Framing is a number: assert minimum
      headroom under the leader in projected pixels, across a whole level, at both forms.
- [ ] **1.4 Wax and wax-coated candles read as wax.** A sheen that moves with the light, so a
      dipped candle is distinguishable from a painted one. NOT DONE. The toon shader is
      `specular_disabled` on purpose, so this is a shader change rather than a material one,
      and it has to be measured against the pale-surface blowout that set the current
      lighting - a cream candle on a white runway is the case that breaks first.

### Phase 2 — feedback, which is what "better than hers" mostly means

The reference shows floating green `+143$` text where the value happened. Ours has one 2D
toast label that says `-3` in the corner. Value is the whole point of the game and it is
currently invisible.

- [x] **2.1 Value appears where it is earned.** World-space floating text at the candle that
      was dipped, the note that was taken, the station that fired — green for money, white for
      a coat. Pooled, never allocated per event.
- [x] **2.2 A dip splashes, glitter sparkles, a hit bursts.** `assets/particles/` already has
      droplet, glitter and glow and only the ladle's pour uses any of them.
- [x] **2.3 A hit is felt.** Camera kick and a colour flash on losing candles, and the frame
      after the hit shows it. Rate-limited so a five-candle loss is one kick, not five.

### Phase 3 — the reference's last open items

Straight off `REFERENCE.md`'s own "Still open" list, which has sat unworked for three rounds.

- [x] **3.1 The finished batch stands on a dark navy podium** at the ruler, instead of being
      lit in place on the runway. Screenshot 5 shows it clearly.
- [x] **3.2 Price tags carry their number.** Theirs read `5 $`, `154 $`; ours are blank.
- [ ] **3.3 Shop fronts are bought in the track**, with a green `+` per panel, rather than
      being scenery that opens a sheet. NOT DONE, and the largest remaining reference gap.
      The shop model is right (`shops.gd`, a seven-rung ladder, next-rung-only); what is
      wrong is that buying happens in a sheet instead of on the runway past the finish line.

### Phase 4 — the framework this repo is supposed to be on

Gaps against `gamedev-notes` as of the 2026-09-10 digest, all verified absent.

- [x] **4.1 The Android back button works.** `quit_on_go_back = false` AND
      `NOTIFICATION_WM_GO_BACK_REQUEST` unwinding one layer per press, in the same commit.
      Neither exists today, so the button quits the app mid-run and throws the run away.
      Assert the unwinding, never the setting.
- [x] **4.2 The version cannot drift.** A pure test asserting `Changelog.VERSION` equals
      `version/name` in **each** export preset and `RELEASES[0].version`.
- [x] **4.3 The game can be filmed.** There is no `scripts/movie.ps1` and no `test/replays/`,
      so the studio's primary tool for judging motion has never been available here. Replay
      coordinates go against the **project viewport (~1080x2338)**, not the sheet resolution.

---

## Round four (2026-09-09) — shipped

Kept because each entry records a measurement that is expensive to re-derive. Detail in
`NOTES.md`.

- [x] **A. The crash.** Not reproduced in 150 s of real frames across four levels. Surface
      reduced (materials cached — `_dress_rig` was building ~360 `StandardMaterial3D`s a
      second), the wax shader's noise replaced with a texture, and `blackbox.gd` added so the
      next crash reports itself from a phone with no cable.
- [x] **B. Steering was inverted.** World +x is on screen LEFT, so the drag handler must
      subtract and it added. Guarded in PIXELS through `unproject_position`, because every
      test that drives `steer_to()` in world coordinates passes either way.
- [x] **C. A dip is a coat, not a stripe.** Each layer is a sleeve from the base up to its own
      height at a slightly larger radius, so earlier layers stay visible as rings and the
      silhouette stays a candle. `RADIUS_PER_LAYER` 0.045 -> 0.012.
- [x] **D. The pour.** A tapered curved stream, a spreading ring where it lands, spatter.
- [x] **E. Imported assets.** ambientCG plastic normal/roughness, Kenney particles, Kenney
      interface and impact sounds. The CC0 libraries have nothing for candles or wax — the
      subject is the problem, not the library, confirmed twice.
- [x] **F. Music.** Four real tracks, generated at build time and committed as files, because
      GDScript synthesises about a million samples a second and every second of audio would
      otherwise be a second of black screen on the phone.
- [x] **G. Sounds.** Kenney interface and impact packs for taps and hits; the synthesised dip
      ladder kept, because its pitch rises with the candle's layer count and a fixed sample
      cannot do that without a folder of variants.
