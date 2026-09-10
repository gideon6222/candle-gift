# Imported assets

Everything here is CC0 (public domain). Nothing needs attribution to be legal;
this file exists so that the next person knows what was taken, from where, and
**what was done to it** — because in two of the three cases the raw asset was
not what went in.

| File | Source | Licence | What was done |
|---|---|---|---|
| `font/Fredoka-Bold.ttf`, `Fredoka-SemiBold.ttf` | Google Fonts | OFL | none |
| `particles/droplet.png` | Kenney *Particle Pack* (`circle_05`) | CC0 | renamed |
| `particles/glitter.png` | Kenney *Particle Pack* (`star_08`) | CC0 | renamed |
| `particles/glow.png` | Kenney *Particle Pack* (`light_01`) | CC0 | renamed |
| `sfx/tap.ogg` | Kenney *Interface Sounds* (`click_002`) | CC0 | renamed |
| `sfx/confirm.ogg` | Kenney *Interface Sounds* (`confirmation_002`) | CC0 | renamed |
| `sfx/deny.ogg` | Kenney *Interface Sounds* (`error_003`) | CC0 | renamed |
| `sfx/back.ogg` | Kenney *Interface Sounds* (`back_002`) | CC0 | renamed |
| `sfx/knock.ogg` | Kenney *Impact Sounds* (`impactSoft_medium_002`) | CC0 | renamed |
| `sfx/finish.ogg` | Kenney *Impact Sounds* (`impactBell_heavy_001`) | CC0 | renamed |
| `music/wisdom.ogg`, `saying.ogg`, `swinging.ogg`, `dust.ogg` | OpenGameArt, *Short Loops Background Music Pack* by **hernandack** | CC0 | renamed |
| `tex/wax_swirl.png` | ambientCG `Marble012`, **Color map** | CC0 | greyscale, Gaussian blur 9 at 1K, autocontrast, resized to 256 |

## Two things learned taking these

**Marble's swirl is PIGMENT, not relief.** The rule this project has used for
every previous import is "take the normal map, leave the colour map", because a
normal is style-neutral and a photograph's colour is not. It does not hold here:
`Marble012`'s normal map is *blank* — every pixel measured at (0.502, 0.498,
1.0) — because polished marble has no surface relief. The pattern only exists in
the colour map. So the colour map came across, converted to **luminance**, which
carries the pattern and none of the hue. The wax's own colour does the rest.

The rule generalises: **take whichever map holds the pattern, and strip whatever
carries the style.** For rock that is the normal. For marble it is the colour,
desaturated.

**A photograph is mostly grain.** At 1K, the marble is far more speckle than
swirl, and speckle scrolled across a pool reads as television static. Blur hard
at full size *then* downscale — blurring after the resize only smears the
aliasing the resize introduced. 9 pixels of Gaussian at 1024 leaves the swirl and
nothing else, and the file drops from 221 KB to 36 KB on the way.

## The music is a CHOICE, not a track

Four loops ship and the pause panel cycles them. That is not indecision: two
music beds were generated for this game, one came back **"creepy"** and its
replacement came back **"chirpy"**, and neither verdict was available to whoever
wrote them. Judging music is exactly the job that cannot be done from the side
that writes the code, and iterating on a taste question you have no access to is
how a week goes sideways.

`Kenney` has no loops at all — only Music Jingles, which are stingers. These came
from OpenGameArt, which does.

## Not imported, and why

Queried on 2026-09-09 for this game's subjects:

- **Poly Haven**, 521 models: `candle` returns four candle*holders*, and nothing
  at all for wax, gift, ribbon, conveyor or jar. Photoreal besides.
- **ambientCG**: `wax`, `candle`, `liquid` and `gift` each return **0 results**.
- **Kenney audio**: no music loops anywhere — Music Jingles is stingers. The
  bed in `sfx.gd` is generated because there is nothing to take.

This confirms what was recorded for Wick, the previous candle game on these
notes: the hit rate is a property of the SUBJECT, not of the library.
