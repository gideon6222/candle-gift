class_name Store
extends RefCounted

## Read a JSON file assuming it is wrong, and write one back.
##
## Shared by `save.gd` and `settings.gd`, which are two FILES on purpose -
## preferences are not progress, and a pause screen that offers to erase your
## progress next to a sound switch only keeps that promise if the two cannot
## touch each other. What they can share is the reading, because "be suspicious
## of the file" is the same job both times and writing it twice means fixing it
## once and forgetting the other.

## Every field comes back, always, coerced to the type of its default.
##
## The two rules that matter, and both have shipped as bugs on this stack:
##
## **A missing key is a key the game has just added**, so it must come back as
## its DEFAULT rather than as null. A save written before a field existed is the
## normal case for anyone upgrading, not an edge case.
##
## **JSON has one number type.** Every int written comes back as a float, so
## `level` loads as 3.0 - which is truthy, prints as "3", compares equal to 3,
## and then indexes an array as a float somewhere completely unrelated.
static func read(path: String, defaults: Dictionary) -> Dictionary:
	var out := defaults.duplicate(true)
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	## The instance form, not `JSON.parse_string`, which pushes an engine error
	## on bad input - so a test that deliberately corrupts a file prints a stack
	## trace while passing, and a suite that prints errors when it is healthy
	## teaches everyone to skip past errors.
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return out
	if typeof(json.data) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = json.data
	for k in defaults:
		if not d.has(k):
			continue
		var got: Variant = d[k]
		match typeof(defaults[k]):
			TYPE_FLOAT:
				if got is float or got is int:
					out[k] = float(got)
			TYPE_INT:
				if got is float or got is int:
					out[k] = int(got)
			TYPE_BOOL:
				## `== true` rather than truthiness. A field written as 0, "" or
				## null must read as OFF rather than as "not set", and a field
				## the file has never heard of has already been skipped above -
				## so this cannot silently turn a default-on switch off for
				## everyone upgrading.
				out[k] = got == true
			TYPE_ARRAY:
				## Rebuilt element by element rather than trusted. A hand-edited
				## or future-version file can put anything in here, and a value
				## of the wrong type would reach `Array.has()` and quietly never
				## match - so the player would own something that grants nothing.
				if got is Array:
					var ids: Array = []
					for v in got:
						if v is String and not ids.has(v):
							ids.append(v)
					out[k] = ids
			_:
				out[k] = got
	return out


## Only the known fields are written, so a stray key cannot survive a round trip
## and come back looking official.
static func write(path: String, defaults: Dictionary, state: Dictionary) -> void:
	var out := defaults.duplicate(true)
	for k in defaults:
		if state.has(k):
			out[k] = state[k]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(out))


static func erase(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
