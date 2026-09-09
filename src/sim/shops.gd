class_name Shops
extends RefCounted

## PROGRESSION IS BUYING SHOPS, not buying stats.
##
## This is the reference's whole meta-game and it took a store review to spot:
## there is no upgrade sheet anywhere in six levels of footage, no list of
## numbers with buy buttons. What the player buys is a new SHOP, and a shop is a
## new station on the runway or a better product coming off it.
##
## Bigger Batch, Steady Tray, Long Reach, Deeper Vats and the Glitter Cannon were
## invented for an earlier build of this game, appear nowhere in the reference,
## and are gone. `REFERENCE.md` has the two observed prices.
##
## Each entry `grants` exactly one field on `Sim`, and the value it grants is
## absolute rather than an increment - so buying the same shop twice cannot
## happen, and a save that somehow contains it twice still lands on the right
## number.

const ONLINE := "online"
const BOUTIQUE := "boutique"
const SCENT := "scent"
const LUXURY := "luxury"
const DEPARTMENT := "department"
const ATELIER := "atelier"
const FLAGSHIP := "flagship"

## Ordered, and the order IS the ladder: the list is walked in order to find
## what to offer next, so a shop cannot be bought before the one under it.
##
## The first four names and the two prices marked are the reference's. The last
## three are ours - the reference's footage stops at level six and shows four
## shops, and stopping there would leave the third mould and the third wrap
## unreachable, which is content the game already has and could never show.
const ALL := [
	{
		"id": ONLINE, "name": "ONLINE SHOP", "price": 1000.0,          # observed
		"blurb": "Sell online. Every candle is worth more.",
		"field": "earn_level", "value": 1,
	},
	{
		"id": BOUTIQUE, "name": "BOUTIQUE", "price": 2500.0,
		"blurb": "A better press. Fluted candles.",
		"field": "press_level", "value": 1,
	},
	{
		"id": SCENT, "name": "SCENT SHOP", "price": 4000.0,            # observed
		"blurb": "Opens the scent station on the runway.",
		"field": "has_scent", "value": true,
	},
	{
		"id": LUXURY, "name": "LUXURY SHOP", "price": 9000.0,
		"blurb": "Ribbon and a bow at the gift table.",
		"field": "wrap_level", "value": 1,
	},
	{
		"id": DEPARTMENT, "name": "DEPARTMENT STORE", "price": 22000.0,
		"blurb": "A whole floor of candles. Worth more again.",
		"field": "earn_level", "value": 2,
	},
	{
		"id": ATELIER, "name": "ATELIER", "price": 48000.0,
		"blurb": "The twist die, and then the star.",
		"field": "press_level", "value": 2,
	},
	{
		"id": FLAGSHIP, "name": "FLAGSHIP STORE", "price": 110000.0,
		"blurb": "Boxed and finished. The best a candle gets.",
		"field": "wrap_level", "value": 2,
	},
]


static func by_id(id: String) -> Dictionary:
	for s in ALL:
		if String(s.id) == id:
			return s
	return {}


## What the player owns, as a set of ids, resolved into the fields `Sim` reads.
##
## Derived rather than stored. A field kept beside the list of owned shops is a
## second source of truth, and the two drift the first time a shop is added in
## the middle of the ladder - which is exactly when nobody is looking.
static func stats_for(owned: Array) -> Dictionary:
	var out := {
		"earn_level": 0,
		"press_level": 0,
		"wrap_level": 0,
		"has_scent": false,
	}
	for s in ALL:
		if not owned.has(String(s.id)):
			continue
		var field := String(s.field)
		if field == "has_scent":
			out[field] = true
		else:
			out[field] = maxi(int(out[field]), int(s.value))
	return out


## The next shop that is not owned, or an empty dictionary once they all are.
static func next_for(owned: Array) -> Dictionary:
	for s in ALL:
		if not owned.has(String(s.id)):
			return s
	return {}


static func owns(owned: Array, id: String) -> bool:
	return owned.has(id)


## Buyable only if it is the next rung and there is the money for it.
##
## The ladder matters: without it a lucky run could buy the FLAGSHIP STORE and
## skip every shop under it, and the player would own the best wrap while the
## press was still stamping PLAIN.
static func can_buy(owned: Array, cash: float, id: String) -> bool:
	var s := by_id(id)
	if s.is_empty() or owned.has(id):
		return false
	var next := next_for(owned)
	if next.is_empty() or String(next.id) != id:
		return false
	return cash >= float(s.price)
