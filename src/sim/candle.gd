class_name Candle
extends RefCounted

## ONE candle's recipe, and everything that follows from it.
##
## **Every candle in the batch carries its own recipe.** That is the single most
## important fact in this game. Wax is a POOL ON THE GROUND, roughly half the
## width of the track, so which candles get which colour depends on where each
## one was as the batch snaked over it - and because the batch trails along the
## leader's recorded path, THE PLAYER'S LINE IS THE DECISION.
##
## The reference's own strategy guide says it outright: *"if there are two pools
## of wax side by side, you should swipe left and right quickly to try and dunk
## all of your candles in both of the pools."* Treating the batch as one shared
## recipe deletes that entire skill, and measured on the sibling build it
## produced an identical per-candle value across every way of playing - never
## touching the screen scored what playing perfectly scored.
##
## The other rule: **the silhouette is derived from the recipe, never stored
## beside it.** Radius, height and value are all functions of the same object,
## so the candles on screen cannot disagree with the candles being paid for.

## Wax indices, oldest first. A candle always starts as cream.
var layers: Array[int] = [Wax.CREAM]
var glitter: int = 0
var scent: int = 0
var mould: int = 0
var wrap: int = 0

## Which station half last treated this candle. Stops a pool re-dipping the same
## candle on every frame it stands in it, without the pool having to remember
## anything about the batch.
var mark: int = -1


static func make() -> Candle:
	return Candle.new()


func clone() -> Candle:
	var c := Candle.new()
	c.layers = layers.duplicate()
	c.glitter = glitter
	c.scent = scent
	c.mould = mould
	c.wrap = wrap
	c.mark = mark
	return c


func top_wax() -> int:
	return layers[layers.size() - 1]


## Dip into a wax. Returns whether anything happened.
##
## Refuses a colour the candle already wears on top, which is why no workshop
## offers CREAM at a pool: cream is the core, so a cream pool would be a station
## with a gantry and a sign that does nothing, and it reads on screen only as a
## batch that stubbornly stays beige.
func dip(wax: int) -> bool:
	if layers.size() >= Tuning.MAX_LAYERS:
		return false
	if top_wax() == wax:
		return false
	layers.append(wax)
	return true


func add_glitter(n: int) -> bool:
	if glitter >= Tuning.MAX_GLITTER:
		return false
	glitter = mini(Tuning.MAX_GLITTER, glitter + n)
	return true


func add_scent() -> bool:
	if scent > 0:
		return false
	scent = 1
	return true


func press(m: int) -> bool:
	if m <= mould:
		return false
	mould = m
	return true


func wrap_in(w: int) -> bool:
	if w <= wrap:
		return false
	wrap = w
	return true


# --- geometry, derived ----------------------------------------------------

func radius() -> float:
	return Tuning.CORE_RADIUS + float(layers.size() - 1) * Tuning.RADIUS_PER_LAYER


## The radius at each band, innermost first. A candle is a LAYER CAKE, not an
## onion: dips are bands stacked along it, newest on the outside end, and each
## band is drawn at the radius the candle had when it was applied.
##
## Modelled as concentric shells - which is what dipping physically does - the
## outermost band hides every band inside it and five dips render as a plain
## cylinder. That shipped once.
func radii() -> Array[float]:
	var out: Array[float] = []
	for i in layers.size():
		out.append(Tuning.CORE_RADIUS + float(i) * Tuning.RADIUS_PER_LAYER)
	return out


## HOW FAR UP THE CANDLE EACH COAT REACHES, newest last.
##
## A DIP IS A COAT, NOT A STRIPE. Each one covers the candle from the base up to
## a height, and each successive one reaches a little less far - so the newest
## wax is the widest and lowest, and every earlier layer stays visible as a ring
## above it. That is what dipping a candle repeatedly actually does.
##
## The old model cut the candle into equal slices and gave each slice its own
## radius, which built a stepped cone: on the phone it read as "little blocks",
## which is exactly what it was. It is also not the onion model, which was tried
## and rejected on the sibling build - concentric shells hide every layer inside
## the outermost, and five dips render as a plain cylinder.
func coat_heights() -> Array[float]:
	## EVENLY SPACED. The oldest coat reaches the top of the candle and the
	## newest reaches a fraction of the way up, so what you see is n bands of
	## equal height with the newest at the BOTTOM - which is where the wax
	## goes when you dip something.
	##
	## Spacing them by a fixed drop per layer instead made the newest colour
	## cover sixty per cent of the candle and squeezed everything else into
	## rings at the top.
	var l := length()
	var n := maxi(1, layers.size())
	var out: Array[float] = []
	for i in n:
		out.append(l * float(n - i) / float(n))
	return out


## Kept as the thickness of the ring each coat leaves exposed, which is what the
## renderer needs to know to draw a rim on it.
func band_height() -> float:
	return length() / float(maxi(1, layers.size()))


## Where each coat's exposed ring sits, measured from the base. The last entry
## is the top of the newest coat; earlier ones are further up the candle.
func band_offsets() -> Array[float]:
	return coat_heights()


func length() -> float:
	return Tuning.CANDLE_LENGTH + float(layers.size() - 1) * Tuning.BAND_HEIGHT


# --- value, derived -------------------------------------------------------

## How many adjacent pairs of bands actually read as two different colours.
## Rewards a line that alternates rather than one that piles on more of the same.
func contrast_pairs() -> int:
	var n := 0
	for i in range(1, layers.size()):
		if Wax.reads_as_two(layers[i - 1], layers[i]):
			n += 1
	return n


func colour_count() -> int:
	var seen := {}
	for w in layers:
		seen[w] = true
	return seen.size()


## The sum of what the waxes on it are worth.
func wax_value() -> float:
	var v := 0.0
	for w in layers:
		v += Wax.price(w)
	return v


## Everything done to it beyond the wax, as a multiplier.
func craft() -> float:
	var m: Dictionary = Wax.MOULDS[mould]
	var w: Dictionary = Wax.WRAPS[wrap]
	return (1.0 + float(glitter) * Tuning.GLITTER_VALUE) \
		* (1.0 + float(scent) * Tuning.SCENT_VALUE) \
		* float(m.mul) * float(w.mul)


func value() -> float:
	var base := Tuning.BASE_VALUE
	base += float(layers.size() - 1) * Tuning.LAYER_VALUE * Tuning.BASE_VALUE
	base += float(contrast_pairs()) * Tuning.CONTRAST_VALUE * Tuning.BASE_VALUE
	return base * wax_value() * craft()
