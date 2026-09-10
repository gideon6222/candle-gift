extends SceneTree

## PLAY IT FOR REAL, WITH FRAMES, AND SEE IF IT FALLS OVER.
##
##   godot --path . --resolution 460x996 --script res://scripts/soak.gd -- 120
##
## Everything else here steps the simulation in a loop inside one frame. That is
## right for determinism and it cannot see a class of bug that only exists when
## the renderer runs every frame for minutes: a MultiMesh overflowing its pool,
## a node pool exhausted, a buffer that grows without bound.
##
## Reported crash: about twenty seconds into moving. A level is ~35 s and the
## ROTATE wall is at ~17.7 s, so twenty seconds is a second or two AFTER the
## batch stands up - which is the one moment the renderer changes shape.

var _main
var _f := 0
var _t := 0.0
var _seconds := 120.0
var _mem := {}
var _last_report := 0.0
var _peak := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		_seconds = float(a)
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()


func _process(delta: float) -> bool:
	_f += 1
	if _f < 3:
		return false

	## A real frame, at a real delta, driven by a real policy.
	var step: float = clampf(delta, 1.0 / 240.0, 1.0 / 20.0)
	Policies.steer(Policies.WEAVE, _main.sim, _mem)
	_main.advance(step, step)
	_t += step

	## The reward screen would otherwise stop the run dead; take it and carry on
	## so this covers several levels rather than one.
	if _main._phase == _main.Phase.REWARD:
		_main._take_reward()
		_main._set_phase(_main.Phase.RUN)

	_watch()

	if _t - _last_report >= 5.0:
		_last_report = _t
		## WHAT IS GROWING. A crash twenty seconds in on a phone that never
		## happens here is almost always something accumulating - objects,
		## RIDs, memory - fast enough to matter with 8 GB and fatal with less.
		print("  t=%6.1fs  level %d  candles %2d  objects %6d  orphans %5d  static %6.1f MB  video %6.1f MB" % [
			_t, _main.sim.level, _main.sim.count(),
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])

	if _t >= _seconds:
		print("")
		print("  survived %.0f s. peak instance counts against their pools:" % _t)
		for k in _peak:
			print("    %-14s %4d / %4d" % [k, _peak[k][0], _peak[k][1]])
		quit(0)
		return true
	return false


## THE POOLS, every frame.
##
## A MultiMesh whose `visible_instance_count` reaches `instance_count` is not an
## error - it silently stops drawing the rest - and the write that goes past the
## end IS an error. Either way the number to watch is how close each one gets.
func _watch() -> void:
	var named := {
		"bands": _main._bands[0], "wicks": _main._wicks, "ribbons": _main._ribbons,
		"bows": _main._bows, "sparks": _main._sparks, "loose": _main._loose,
		"notes": _main._notes, "barriers": _main._barriers, "spikes": _main._spikes,
		"bar_marks": _main._bar_marks, "sweepers": _main._sweepers,
		"towers": _main._towers, "posts": _main._posts,
	}
	for k in named:
		var mm: MultiMesh = named[k].multimesh
		var used := mm.visible_instance_count
		if not _peak.has(k) or used > _peak[k][0]:
			_peak[k] = [used, mm.instance_count]
	var total := 0
	for m in _main._bands:
		total += m.multimesh.visible_instance_count
	if not _peak.has("bands(all)") or total > _peak["bands(all)"][0]:
		_peak["bands(all)"] = [total, _main._bands[0].multimesh.instance_count]
