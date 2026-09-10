extends SceneTree

## WHERE IN THE FRAME DOES THE BATCH SIT, across a whole level, in both forms?
##
##   godot --path . --headless --script res://scripts/framing.gd -- 1
##
## The contact sheet showed the front of the batch cut off by the bottom edge
## once it stood up. That is a framing bug, and framing is a NUMBER: how far
## down the frame the nearest thing the player owns is drawn.
##
## Computed from the CAMERA, not from `unproject_position`, and that is the
## whole reason this script exists rather than a line in the smoke suite.
## `unproject_position` divides by the viewport size, and a headless viewport is
## 100x100 - so every absolute pixel it reports is against a square screen the
## phone never shows. The vertical framing does not actually depend on the
## viewport at all: `Camera3D.keep_aspect` defaults to KEEP_HEIGHT, so `fov` is
## the VERTICAL angle and the horizontal one is derived from the aspect. Project
## onto the vertical axis by hand and the answer is the same headless, on the
## desk and on the phone.
##
## 0.0 is the top of the frame and 1.0 is the bottom.

var _main
var _level := 1
var _worst_seen := 0.0
var _frames := 0


## THE MEASURING RUNS AFTER REAL FRAMES, not inside `_initialize`.
##
## `add_child` during `_initialize` does not put the node in the tree until the
## first processed frame, and the game plays sounds as it goes - so measuring
## straight away printed "Playback can only happen when a node is inside the
## scene tree" once per pickup. `scripts/check.sh` fails on any `ERROR:` line
## and it is right to: an error nobody has to act on is an error everyone
## learns to scroll past. Same three-frame wait as `run_smoke.gd`.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_level = int(args[0])

	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	_measure()
	return true


func _measure() -> void:
	_main.freeze(_level)

	var span := Tuning.level_seconds(_level)
	var mem := {}
	var worst_flat := 0.0
	var worst_stand := 0.0
	var worst_flat_t := 0.0
	var worst_stand_t := 0.0
	var t := 0.0
	var step := 1.0 / 30.0
	while t < span:
		Policies.steer(Policies.WEAVE, _main.sim, mem)
		_main.advance(step, 1.0 / 60.0)
		t += step
		## THE WHOLE BATCH, not the leader.
		##
		## The first draft of this measured the leader and reported a
		## comfortable 0.71 across three levels while the contact sheet plainly
		## showed the batch cut off by the bottom edge. The leader is the
		## FURTHEST candle from the camera - the batch trails BACKWARD toward
		## the lens - so the thing that gets clipped is the tail, and measuring
		## the leader is measuring the end that was never at risk.
		##
		## Every candle, because which one is lowest changes: through a turn the
		## trail snakes and a middle candle can swing nearer the lens than the
		## last one.
		var f := 0.0
		for p in _main.sim.positions():
			f = maxf(f, _frac(Vector3(p.x, 0.0, p.y)))
		_worst_seen = maxf(_worst_seen, f)
		if _main.sim.standing:
			if f > worst_stand:
				worst_stand = f
				worst_stand_t = t
		else:
			if f > worst_flat:
				worst_flat = f
				worst_flat_t = t

	print("  level %d, weaving, %.1f s" % [_level, span])
	print("    lying    worst %.4f down the frame  at t=%5.1fs" % [worst_flat, worst_flat_t])
	print("    standing worst %.4f down the frame  at t=%5.1fs" % [worst_stand, worst_stand_t])
	print("    (1.0 is the bottom edge; anything at or past it is clipped)")
	quit(0)


## ONE SOURCE OF TRUTH for "how far down the frame". `main.gd` solves the
## camera against this same arithmetic, so a probe with its own copy of it would
## agree with the game right up until one of them was edited. Delegate.
func _frac(p: Vector3) -> float:
	return _main._frac_of(_main._cam.transform, p)
