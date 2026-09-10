class_name BlackBox
extends RefCounted

## WHAT HAPPENED LAST TIME, when the game did not come back.
##
## Gideon's phone crashes after about twenty seconds of play. It does not
## reproduce on this machine - 150 s across four levels with real frames, every
## MultiMesh pool inside bounds, object count and memory flat - and there is no
## device attached here, so there is no logcat and no stack.
##
## So the build has to report on itself. Godot writes every error and every
## `print` to `user://logs/godot.log` when file logging is on. This writes a
## marker at boot and clears it on a clean exit; if the marker is still there at
## the next boot, the last session ended without one, and the tail of that log is
## the only evidence of why. It goes on screen so it can be screenshotted, which
## is the only channel back from a phone with no cable.
##
## It costs one small file write per launch and nothing while playing.

const MARKER := "user://running.marker"
const LOG := "user://logs/godot.log"
const TAIL_LINES := 26


## Called at boot, BEFORE anything that might bring the game down.
static func arm(version: String) -> void:
	var f := FileAccess.open(MARKER, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("%s|%s|%s" % [version, Time.get_datetime_string_from_system(), OS.get_model_name()])


## Called on a clean exit. If this never runs, the marker survives and the next
## boot knows the session died.
static func disarm() -> void:
	if FileAccess.file_exists(MARKER):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MARKER))


static func crashed_last_time() -> bool:
	return FileAccess.file_exists(MARKER)


static func last_session() -> String:
	if not FileAccess.file_exists(MARKER):
		return ""
	var f := FileAccess.open(MARKER, FileAccess.READ)
	return "" if f == null else f.get_as_text()


## The tail of the previous log, newest last.
##
## Read BEFORE this session has written much to it - Godot appends, and it keeps
## a handful of rotated copies, so a boot that happens to be chatty would
## otherwise push the interesting part out of the window.
static func tail() -> String:
	if not FileAccess.file_exists(LOG):
		return "(no log file - file logging is off)"
	var f := FileAccess.open(LOG, FileAccess.READ)
	if f == null:
		return "(log could not be opened)"
	var lines := f.get_as_text().split("\n", false)
	var out := PackedStringArray()
	var first: int = maxi(0, lines.size() - TAIL_LINES)
	for i in range(first, lines.size()):
		## Trimmed hard: this is going on a phone screen, not into a terminal.
		out.append(lines[i].substr(0, 96))
	return "\n".join(out)
