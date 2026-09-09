class_name Save
extends RefCounted

## The one save file, and a loader that assumes the file is wrong.
##
## `user://` rather than a path of our own: it is the only location that is
## writable on every platform this can be exported to, and on Android it is
## inside the app's private storage, so it survives an update and goes away with
## an uninstall.
##
## PREFERENCES ARE NOT PROGRESS and will not share this file when they arrive.
## A settings panel offers to erase your progress next to switches that control
## sound, and that promise only holds if the two are separate things.

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
}

## A ONE-WAY LATCH. Erasing the save and then quitting used to put it straight
## back: the game saves when it loses focus, and clearing progress is followed
## immediately by exactly that. So a wipe makes `store` a no-op for the rest of
## the process, and the only way back is a restart - by which time the file is
## genuinely gone.
static var _wiped := false


static func load_state() -> Dictionary:
	var out := DEFAULTS.duplicate()
	if not FileAccess.file_exists(PATH):
		return out
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return out
	## `JSON.parse_string` pushes an engine error on bad input, so a test that
	## deliberately corrupts the file prints a stack trace while passing. A
	## suite that prints errors when it is healthy teaches everyone to skip
	## past errors. The instance form returns a code instead.
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return out
	if typeof(json.data) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = json.data
	for k in DEFAULTS:
		if not d.has(k):
			continue
		## Coerced to the type of the DEFAULT rather than trusted.
		##
		## JSON has one number type, so every int in the file comes back as a
		## float and `level` becomes 3.0 - which is truthy, prints as "3", and
		## then indexes an array as 3.0 and fails somewhere else entirely.
		var want := typeof(DEFAULTS[k])
		var got: Variant = d[k]
		match want:
			TYPE_FLOAT:
				if got is float or got is int:
					out[k] = float(got)
			TYPE_INT:
				if got is float or got is int:
					out[k] = int(got)
			TYPE_BOOL:
				out[k] = got == true
			_:
				out[k] = got
	out.level = maxi(1, int(out.level))
	out.cash = maxf(0.0, float(out.cash))
	out.best = maxf(0.0, float(out.best))
	return out


static func store(state: Dictionary) -> void:
	if _wiped:
		return
	var out := DEFAULTS.duplicate()
	for k in DEFAULTS:
		if state.has(k):
			out[k] = state[k]
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(out))


static func wipe() -> void:
	_wiped = true
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## For tests, which need a fresh latch per case.
static func _reset_latch_for_tests() -> void:
	_wiped = false
