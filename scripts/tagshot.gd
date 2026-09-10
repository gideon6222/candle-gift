extends SceneTree
## One-off: find a moment where a BIG price tag is ahead of the batch and shoot
## it, so the denominations can be LOOKED at rather than only asserted.
##
##   godot --path . --resolution 460x996 --script res://scripts/tagshot.gd -- 6
##
## Same shape as `shot.gd`: all the playing happens in `_initialize` and the
## capture waits five real frames, because the sky, the shadow map and the
## MultiMesh buffers have to have been drawn once. And it tears the scene down
## before quitting, or the exit prints "N resources still in use".
var _main
var _frames := 0
var _level := 6
var _found := -1.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		_level = int(a)
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze(_level)
	var mem := {}
	for step in 4000:
		Policies.steer(Policies.GATHER, _main.sim, mem)
		_main.advance(1.0 / 60.0, 1.0 / 60.0)
		for b in _main.sim.notes:
			if int(b.get("tier", 0)) < 2:
				continue
			var ahead: float = float(b.z) - _main.sim.distance
			if ahead > 6.0 and ahead < 11.0:
				_found = ahead
				break
		if _found > 0.0 or _main.sim.over:
			break


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false
	if _found < 0.0:
		print("  no big tag came into view on level %d" % _level)
	else:
		root.get_texture().get_image().save_png("user://tagshot.png")
		for t in _main._note_tags:
			if not t.visible:
				continue
			var f: float = _main._frac_of(_main._cam.transform, t.position)
			print("    tag %-8s at %.2f down the frame, %.1f m ahead"
				% [t.text, f, t.position.z - _main.sim.distance])
		print("  big tag %.1f m ahead on level %d -> %s/tagshot.png"
			% [_found, _level, OS.get_user_data_dir()])
	if _main != null:
		if _main.has_method("_sfx_stop"):
			_main.call("_sfx_stop")
		if _main.get_parent() != null:
			_main.get_parent().remove_child(_main)
		_main.free()
	quit(0)
	return true
