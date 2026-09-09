class_name Save
extends RefCounted

## The one save file, and a loader that assumes the file is wrong.
##
## `user://` rather than a path of our own: it is the only location that is
## writable on every platform this can be exported to, and on Android it is
## inside the app's private storage, so it survives an update and goes away with
## an uninstall.
##
## PREFERENCES ARE NOT PROGRESS and do not share this file - `settings.gd` owns
## its own. A settings panel offers to erase your progress next to switches that
## control sound, and that promise only holds if the two are separate things.
##
## The defensive reading lives in `store.gd`. Both files need it, and writing it
## twice means fixing it once and forgetting the other.

const PATH := "user://candlegift.v1.json"

## Every field, with the value a fresh install gets. The loader reads THIS, not
## the file: a key the file has never heard of is a key the game has just added,
## and it has to come back as its default rather than as null.
const DEFAULTS := {
	"cash": 0.0,
	"level": 1,
	"best": 0.0,
	"earn_level": 0,
	"press_level": 0,
	"wrap_level": 0,
	"has_scent": false,
	## THE SHOPS OWNED, as ids. The stats above are DERIVED from this by
	## `Shops.stats_for` - they are still in the file because a save written
	## before the shop existed has them, and dropping them would silently
	## demote anyone upgrading. `Shops` wins wherever the two disagree.
	"owned": [],
}

## A ONE-WAY LATCH. Erasing the save and then quitting used to put it straight
## back: the game saves when it loses focus, and clearing progress is followed
## immediately by exactly that. So a wipe makes `store` a no-op for the rest of
## the process, and the only way back is a restart - by which time the file is
## genuinely gone.
static var _wiped := false


static func load_state() -> Dictionary:
	var out := Store.read(PATH, DEFAULTS)
	## Clamped after reading. These three are the ones a corrupt or hand-edited
	## file can make nonsense of in a way the type coercion cannot catch: a
	## level of -4 and a negative balance are both perfectly good numbers.
	out.level = maxi(1, int(out.level))
	out.cash = maxf(0.0, float(out.cash))
	out.best = maxf(0.0, float(out.best))
	return out


static func store(state: Dictionary) -> void:
	if _wiped:
		return
	Store.write(PATH, DEFAULTS, state)


static func wipe() -> void:
	_wiped = true
	Store.erase(PATH)


## For tests, which need a fresh latch per case.
static func _reset_latch_for_tests() -> void:
	_wiped = false
