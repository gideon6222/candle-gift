class_name BlackBox
extends RefCounted

## WHAT HAPPENED LAST TIME, when the game did not come back.
##
## Gideon's phone crashes after about twenty seconds of play. It does not
## reproduce on this machine - 150 s across four levels with real frames, every
## MultiMesh pool inside bounds, object count and memory flat - and there is no
## device attached here, so there is no logcat and no stack.
##
## So the build reports on itself. Two independent records, because the first
## attempt came back from the phone saying "no log file - file logging is off":
##
##   - **Godot's own log**, which catches engine errors and script errors that
##     nothing in GDScript can see.
##   - **Our own trace**, a line a second of game state, which catches the case
##     where the process dies without printing anything at all - an OOM kill or
##     a driver reset says nothing on its way out, and that is the shape of a
##     crash that only happens on one device.
##
## The marker file is what distinguishes a crash from a clean exit. It goes on
## screen at the next boot to be screenshotted, which is the only channel back
## from a phone with no cable.

const MARKER := "user://running.marker"
const LOG_DIR := "user://logs"
const TRACE := "user://trace.log"
const TAIL_LINES := 18
const TRACE_LINES := 10


static func arm(version: String) -> void:
	var f := FileAccess.open(MARKER, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("%s|%s|%s" % [version, Time.get_datetime_string_from_system(), OS.get_model_name()])


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


## OUR OWN TRACE. One line per second while playing, opened in append mode and
## flushed every time, so whatever is on disk when the process dies is the truth.
##
## Buffered writing would lose exactly the part that matters: the seconds either
## side of the fault are the ones still sitting in the buffer when it goes.
static func trace(line: String) -> void:
	var f := FileAccess.open(TRACE, FileAccess.READ_WRITE) if FileAccess.file_exists(TRACE) \
		else FileAccess.open(TRACE, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.flush()


static func start_trace(version: String) -> void:
	## Truncated per launch: the interesting run is always the last one, and an
	## append-only file on a phone nobody clears grows forever.
	var f := FileAccess.open(TRACE, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("=== %s | %s | %s | %s" % [
		version, OS.get_model_name(), OS.get_name(),
		RenderingServer.get_video_adapter_name()])
	f.flush()


static func trace_tail() -> String:
	return _tail_of(TRACE, TRACE_LINES)


## THE PREVIOUS SESSION'S LOG, WHICH IS NOT `godot.log`.
##
## Godot rotates on every launch: it renames the existing log to a timestamped
## copy and opens a fresh `godot.log`. So by the time anything in the game can
## read it, `godot.log` is THIS session's and is nearly empty. The one that
## matters is the newest timestamped file, and the timestamps sort lexically.
static func tail() -> String:
	var dir := DirAccess.open(LOG_DIR)
	if dir == null:
		return "(no log directory)"
	var rotated := PackedStringArray()
	for f in dir.get_files():
		if f.begins_with("godot") and f.ends_with(".log") and f != "godot.log":
			rotated.append(f)
	if rotated.is_empty():
		return "(no rotated log - this may be the first run since logging was enabled)"
	rotated.sort()
	return _tail_of("%s/%s" % [LOG_DIR, rotated[rotated.size() - 1]], TAIL_LINES)


static func _tail_of(path: String, lines_wanted: int) -> String:
	if not FileAccess.file_exists(path):
		return "(%s is not there)" % path
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "(%s could not be opened)" % path
	var lines := f.get_as_text().split("\n", false)
	var out := PackedStringArray()
	var first: int = maxi(0, lines.size() - lines_wanted)
	for i in range(first, lines.size()):
		## Trimmed hard: this goes on a phone screen, not into a terminal.
		out.append(lines[i].substr(0, 92))
	return "\n".join(out)
