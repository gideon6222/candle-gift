# Plan, 2026-09-09 — the phone build

From Gideon's report after installing build-8: crashes after ~20 s of moving, steering is
backward, candles look like little blocks, dipping should build a full layer rather than add a
stripe, the music is creepy, the pour looks like cylinders, and use pre-made assets wherever
possible.

---

## A. The crash — cannot reproduce, so reduce the surface and make the next one talk

**What was ruled out, with measurements.** `scripts/soak.gd` plays with real frames and real
rendering for 150 s across four levels: no crash, and

- every MultiMesh pool well inside bounds — worst is `bands` at 153 / 240
- object count flat at ~2,150, static memory flat at ~72 MB, video memory flat at ~54 MB
- `Candle.dip` caps at `MAX_LAYERS`, and every instance write is bounds-checked
- the wax shader costs 0.26 ms of a 1.60 ms frame at 1080×2340 (measured against
  `wax_flat.gdshader`, vsync off) — expensive, not fatal, on this GPU

No device is attached to this machine, so there is no logcat. Actions:

1. **Stop allocating materials every frame.** `_dress_rig` calls `_mat()` several times per
   visible station half per frame — roughly 360 new `StandardMaterial3D`s a second, each a new
   RID. Harmless on a desktop with 8 GB of VRAM; churn on a mobile driver. Cache them.
2. **Cut the wax shader.** 13 fbm octaves plus a 3×3 bubble neighbourhood plus a
   fragment-computed normal map, per fragment, over a surface that fills the lower third of the
   screen. Replace the noise with a texture — which is also what D and E want.
3. **Make the next crash report itself.** Enable Godot's file logging, write a marker at boot
   and a clean-exit marker on quit; if the previous session never wrote one, show the tail of
   the log on screen at the next boot so it can be screenshotted. With no adb, this is the only
   diagnostic that reaches back from the phone.
4. **Put the soak in the check suite**, so this class of bug has somewhere to be caught.

## B. Steering — DONE

World +x is on screen LEFT (measured: x=+2 projects to 182, x=−2 to 898 in a 1080-wide frame),
so the drag handler must subtract. It added. `dragging right moves the batch right` asserts it
through `unproject_position`, in pixels — the last game shipped this bug for its whole life
because every test drove `steer_to()` in world coordinates, where the sign is right either way.

## C. Candles look like blocks; a dip should build a layer

The recipe appends a band and the renderer draws each as its own cylinder segment, so a candle
reads as a stack of blocks rather than a dipped object.

**New model: a dip coats the candle from the bottom up to a height that decreases with each
layer, at a slightly larger radius.** That is what repeated dipping physically does, it builds
on itself, and every earlier layer stays visible as a ring above the newest one — so it fixes
"blocks" and "should be a full layer" with the same change, and it keeps the existing invariant
that the silhouette is derived from the recipe and never stored beside it.

It is not the onion model, which was tried and rejected: concentric shells hide every band
inside the outermost, and five dips render as a plain cylinder.

## D. The pour looks like cylinders

A tapered, slightly curved stream that wobbles, a spreading ring where it lands, and spatter
particles. The ladle gets a real lip rather than a cylinder with another cylinder under it.

## E. Assets — what actually exists, queried rather than assumed

| Source | Query | Result |
|---|---|---|
| Poly Haven (521 models) | candle, wax, gift, ribbon, conveyor, jar | **nothing usable** — four candle*holders*, and photoreal |
| ambientCG | wax, candle, liquid, gift | **0 results each** |
| ambientCG | plastic | **28 materials** — a glossy toy surface, normal + roughness |
| ambientCG | marble | 77 — swirled surfaces, for the wax |
| Kenney | Particle Pack | CC0, fetchable unattended |
| Kenney | Interface Sounds, Impact Sounds | CC0, fetchable unattended |
| Kenney | music | **only "Music Jingles"** — stingers, no loops |

This confirms what was recorded for Wick, the previous candle game: **the CC0 libraries have
nothing for candles or wax.** The subject is the problem, not the library. What they do have
that is worth importing here, by the rule in `gamedev-notes/ASSETS.md` — import what the player
reads at full size:

- **ambientCG plastic normal + roughness** for the candles and the wax. Normal and roughness
  are style-neutral; the colour map is not and stays out. The candles are the thing the player
  looks at for the whole game.
- **Kenney Particle Pack** for the pour spatter, the glitter and the confetti, which are
  currently boxes.
- **Kenney Interface + Impact sounds** for taps and hits.

## F. Music — the composition is the problem, not the fidelity

There is no CC0 upbeat loop to import; Kenney has jingles only. The current bed is a
root/fifth/octave drone with a slow swell, which is exactly how you write "creepy". Rewrite it
as a major-key loop at about 120 BPM with a bouncy arpeggio, a bass pulse and a soft kick.

And per `ASSETS.md`, on Godot **generate audio at build time and commit the WAVs** rather than
synthesising at boot: GDScript does about a million samples a second, so every second of audio
is a second of black screen on the phone.

## G. Sounds

Keep the synthesised dip ladder — its pitch rises with the candle's layer count, and a fixed
sample cannot do that without a folder of variants. Import Kenney's Interface and Impact packs
for the taps and the hits, where a produced sample is simply better than a sine blip.

---

## Order

1. A1 material caching, A3 crash log, A4 soak in the suite — the build is unplayable until the
   crash is understood, and A3 is what will actually identify it.
2. C candles.
3. E imports, then D pour and G sounds on top of them.
4. F music.
