extends SceneTree

## A CONTACT SHEET of a whole level, in one run of the engine.
##
##   godot --path . --resolution 460x996 --script res://scripts/sheet.gd -- 12
##
## `shot.gd` answers "does this moment look right" and costs a whole engine
## start per moment, so judging a level through it means guessing which second
## to look at. Most of what is wrong with a runner is only visible as a
## SEQUENCE - a prop that pops in, a sign that sweeps through the middle of the
## frame, a pool that ends before the batch is out of it - and none of that can
## be seen in a single frame chosen in advance.
##
## Same seam as the tests: freeze, then advance in fixed steps, so the nth cell
## is the same moment every time and two sheets a week apart are comparable.
##
## Frames are written one per file and stitched by `scripts/sheet.py`, because
## compositing them here would mean reading pixels back into GDScript.

var _main
var _cells := 12
var _span := 0.0
var _shots: Array[float] = []
var _at := 0
var _settle := 0
var _played := 0.0
const STEP := 1.0 / 60.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_cells = int(args[0])
	if args.size() > 1:
		_span = float(args[1])
	if _span <= 0.0:
		_span = Tuning.level_seconds(1)

	var scene: PackedScene = load("res://src/game/main.tscn")
	_main = scene.instantiate()
	root.add_child(_main)
	_main.freeze()

	# Spread the cells over the level, skipping t=0 - the first cell of a
	# sheet that starts at zero is always the same empty runway.
	for i in _cells:
		_shots.append(_span * float(i + 1) / float(_cells))

	var d := DirAccess.open("user://")
	if d != null and not d.dir_exists("sheet"):
		d.make_dir("sheet")


func _process(_delta: float) -> bool:
	if _at >= _shots.size():
		print("SHEET %s/sheet  cells=%d span=%.1fs" % [OS.get_user_data_dir(), _cells, _span])
		quit(0)
		return true

	# Play forward to this cell's moment, then give the renderer a few frames:
	# the MultiMesh buffers, the shadow map and the sky are all filled during
	# drawing, so capturing on the advance frame gives a stale or grey image.
	if _settle == 0:
		var mem: Dictionary = _main.get_meta("sheet_mem", {})
		while _played < _shots[_at] - STEP * 0.5:
			Policies.steer(Policies.WEAVE, _main.sim, mem)
			_main.advance(STEP, STEP)
			_played += STEP
		_main.set_meta("sheet_mem", mem)

	_settle += 1
	if _settle < 4:
		return false
	_settle = 0

	var img := root.get_texture().get_image()
	img.save_png("user://sheet/cell_%02d.png" % _at)
	print("  cell %2d  t=%5.2fs" % [_at, _played])
	_at += 1
	return false
