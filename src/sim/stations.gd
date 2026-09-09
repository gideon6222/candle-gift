class_name Stations
extends RefCounted

## What each station kind is, and which of them a level lays out where.
##
## A station is a PAIR OF POOLS lying in the runway, side by side, each covering
## roughly half the width - not a gate you pass through. That is the difference
## between a station that happens to you and one you play: a pool is a place, it
## has length, and the batch drives through it, so the candles that end up in the
## left pool are the ones that were on the left when they got there.
##
## Adding a station is a row in `KINDS` plus a slot in `SLOTS`, which is the
## shape that stops "extra stations" becoming a special case scattered through
## the simulation.

const WAX := 0
const GLITTER := 1
const PRESS := 2
const WRAP := 3
const ROTATE := 4
const SCENT := 5

## `liquid` decides whether the renderer builds a tub of wax or a shallow mat -
## a glitter bottle standing in a bathtub it never pours into looks wrong.
## `machine` is what hangs over it.
const KINDS := [
	{"n": "WAX",     "label": "CANDLE", "liquid": true,  "machine": "ladle"},
	{"n": "GLITTER", "label": "GLITTER", "liquid": false, "machine": "bottle"},
	{"n": "PRESS",   "label": "MOLD",   "liquid": false, "machine": "ram"},
	{"n": "WRAP",    "label": "WRAP",   "liquid": false, "machine": "gift"},
	{"n": "ROTATE",  "label": "ROTATE", "liquid": false, "machine": "arrow"},
	{"n": "SCENT",   "label": "SCENT",  "liquid": true,  "machine": "bottle"},
]

## A LEVEL IS TWO SECTIONS, and the ROTATE wall divides them.
##
## Before the wall the candles lie flat and the runway is wax: pools to weave
## through, glitter, scent. The wall spans the whole track, so crossing it is not
## a choice and it fires exactly once. After it the candles stand in a row, and
## the runway is the machines that can only work on a standing candle - the
## press stamps them one at a time, the gift station wraps them.
##
## ROTATE was an ordinary half-station on the sibling build: dodgeable, and able
## to fire twice in a level, which left the press stamping candles lying on
## their sides and made the biggest moment in a run optional.
const SLOTS := [
	# section one: lying down, and it is all wax
	{"c": 4,  "a": WAX,     "b": WAX},
	{"c": 8,  "a": WAX,     "b": GLITTER},
	{"c": 11, "a": WAX,     "b": WAX},
	{"c": 14, "a": WAX,     "b": SCENT},
	# the wall
	{"c": Tuning.ROTATE_CHUNK, "a": ROTATE, "b": ROTATE, "wall": true},
	# section two: standing up, and the machines that need it
	{"c": 20, "a": PRESS,   "b": GLITTER},
	{"c": 23, "a": WAX,     "b": WAX},
	{"c": 26, "a": PRESS,   "b": WRAP},
	{"c": 29, "a": WAX,     "b": GLITTER},
	{"c": 32, "a": WRAP,    "b": WRAP},
]


static func slot_for(c: int) -> Dictionary:
	for s in SLOTS:
		if int(s.c) == c:
			return s
	return {}


static func is_wall(slot: Dictionary) -> bool:
	return slot.has("wall") and bool(slot.wall)


## Which waxes a level offers. CREAM is never among them: it is the candle's own
## core and `dip` refuses a colour already on top, so a cream pool would be a
## dead station. Removing it took average colours per candle from 2.07 to 2.70
## on the sibling build.
const PALETTES := [
	[Wax.BUBBLEGUM, Wax.AQUA, Wax.SUNBEAM],
	[Wax.AQUA, Wax.BUBBLEGUM, Wax.MINT],
	[Wax.SUNBEAM, Wax.BUBBLEGUM, Wax.LILAC],
	[Wax.LILAC, Wax.BUBBLEGUM, Wax.AQUA],
]


static func palette_for(level: int) -> Array:
	return PALETTES[(level - 1) % PALETTES.size()]
