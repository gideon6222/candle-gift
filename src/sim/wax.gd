class_name Wax
extends RefCounted

## The palette, the moulds and the wrappings - the tables every other pure file
## looks things up in.
##
## Colours are here rather than in the renderer because a wax is a piece of
## GAME state: which one a candle is wearing decides what it is worth, and the
## contrast test below is arithmetic on the colour itself. The renderer reads
## these; it does not own them.

## Candy colours, off the reference: hot pink, cyan, mint and gold against a
## pale runway. The warm ones sit close together on the hue wheel on purpose -
## stacking them is the expensive-looking mistake.
##
## `hue` and `lit` are carried alongside the colour because `reads_as_two`
## needs both and deriving them per call turned up in a profile.
const CREAM := 0
const AQUA := 1
const BUBBLEGUM := 2
const SUNBEAM := 3
const MINT := 4
const LILAC := 5

const WAXES := [
	{"n": "CREAM",     "col": Color(1.000, 0.941, 0.816), "hue": 0.11, "lit": 0.92, "price": 1.00},
	{"n": "AQUA",      "col": Color(0.310, 0.890, 0.941), "hue": 0.51, "lit": 0.78, "price": 1.20},
	{"n": "BUBBLEGUM", "col": Color(1.000, 0.239, 0.573), "hue": 0.94, "lit": 0.52, "price": 1.30},
	{"n": "SUNBEAM",   "col": Color(1.000, 0.831, 0.161), "hue": 0.14, "lit": 0.80, "price": 1.35},
	{"n": "MINT",      "col": Color(0.369, 0.941, 0.659), "hue": 0.41, "lit": 0.82, "price": 1.45},
	{"n": "LILAC",     "col": Color(0.690, 0.482, 1.000), "hue": 0.73, "lit": 0.63, "price": 1.55},
]

## The press stamps a cross-section, and the shape is the point: `sides` and
## `bulge` are read by the renderer to build the actual mesh, so the machine
## standing over the track is visibly the shape the candles come out as.
const MOULDS := [
	{"n": "PLAIN",  "sides": 16, "twist": 0.00, "bulge": 0.00, "mul": 1.00},
	{"n": "FLUTED", "sides": 12, "twist": 0.00, "bulge": 0.16, "mul": 1.35},
	{"n": "TWIST",  "sides": 8,  "twist": 1.40, "bulge": 0.15, "mul": 1.60},
	{"n": "STAR",   "sides": 6,  "twist": 0.00, "bulge": 0.34, "mul": 1.90},
]

## Wrapping ties a ribbon and a bow round each candle, which is what the
## reference's gift station does. Biggest single multiplier, and it sits late on
## the runway, in the standing section where a bow can actually be seen.
const WRAPS := [
	{"n": "BARE",   "col": Color.BLACK,                  "bow": Color.BLACK,                  "mul": 1.00},
	{"n": "RIBBON", "col": Color(1.000, 0.239, 0.573),   "bow": Color(1.000, 0.831, 0.161),   "mul": 1.45},
	{"n": "BOXED",  "col": Color(0.847, 0.925, 1.000),   "bow": Color(1.000, 0.239, 0.573),   "mul": 1.90},
	{"n": "LUXE",   "col": Color(1.000, 0.831, 0.161),   "bow": Color(1.000, 0.239, 0.573),   "mul": 2.40},
]


static func hue_gap(a: float, b: float) -> float:
	var d := fmod(absf(a - b), 1.0)
	return 1.0 - d if d > 0.5 else d


## Whether two waxes read as two colours at arm's length.
##
## Hue distance alone is WRONG, and a unit test caught it before it was ever
## drawn: cream and bubblegum are near neighbours on the wheel and obviously two
## colours, because one of them is nearly white. Either axis counts.
static func reads_as_two(a: int, b: int) -> bool:
	var wa: Dictionary = WAXES[a]
	var wb: Dictionary = WAXES[b]
	return hue_gap(wa.hue, wb.hue) > 0.18 or absf(float(wa.lit) - float(wb.lit)) > 0.30


static func colour(i: int) -> Color:
	var w: Dictionary = WAXES[i]
	return w.col


static func price(i: int) -> float:
	var w: Dictionary = WAXES[i]
	return w.price


static func name_of(i: int) -> String:
	var w: Dictionary = WAXES[i]
	return w.n
