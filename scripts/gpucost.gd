extends SceneTree

## HOW EXPENSIVE IS THE WAX SHADER, in frame time?
##
##   godot --path . --resolution 1080x2340 --script res://scripts/gpucost.gd -- wax
##   godot --path . --resolution 1080x2340 --script res://scripts/gpucost.gd -- plain
##
## The reported crash is on an Adreno after about twenty seconds of play, and it
## does not reproduce on this desktop at all. A fragment shader that is merely
## slow on a 2060 can be a driver reset on a phone, so the number worth having
## is how much of a frame the wax is taking when a pool fills the screen.

var _main
var _f := 0
var _mode := "wax"
var _mem := {}
var _samples: Array[float] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		_mode = a
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()
	## Park the batch right in the first pool, so the wax fills the lower frame -
	## the worst case, and the one the player is looking at most of the time.
	_main.advance(4.4, 1.0 / 60.0)
	## VSYNC OFF, or every measurement is the refresh rate. The first version of
	## this reported 8.33 ms for both cases - which is 120 Hz, not a shader.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	## WHAT DO THE SHADOWS COST? Added when the sun first cast one, because
	## "shadows are cheap enough" is a caution and this repo replaces cautions
	## with numbers. Same scene, same 240 frames, one boolean apart.
	if _mode == "noshadow":
		for c in _main.get_children():
			if c is DirectionalLight3D:
				c.shadow_enabled = false
	if _mode == "plain":
		## The SAME uniforms, so `_dress_rig` keeps working - swapping in a
		## StandardMaterial3D made every `set_shader_parameter` fail once a
		## frame, and the "cheap" case measured slower than the expensive one.
		var flat: Shader = load("res://assets/shaders/wax_flat.gdshader")
		for rig in _main._rigs:
			for h in rig.get_meta("halves"):
				var liq: MeshInstance3D = h.liquid
				var m: ShaderMaterial = liq.material_override
				m.shader = flat


func _process(delta: float) -> bool:
	_f += 1
	if _f < 20:
		return false
	Policies.steer(Policies.WEAVE, _main.sim, _mem)
	_main.advance(1.0 / 60.0, 1.0 / 60.0)
	_samples.append(delta * 1000.0)
	if _samples.size() < 240:
		return false
	_samples.sort()
	var mean := 0.0
	for v in _samples:
		mean += v
	mean /= float(_samples.size())
	print("  %-6s  mean %6.2f ms   p50 %6.2f   p95 %6.2f   worst %6.2f" % [
		_mode, mean, _samples[_samples.size() / 2],
		_samples[int(_samples.size() * 0.95)], _samples[_samples.size() - 1]])
	quit(0)
	return true
