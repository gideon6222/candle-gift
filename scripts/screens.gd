extends SceneTree

## One frame of each SCREEN, for looking at.
##
## `sheet.gd` sweeps a level and never leaves the run; the home screen, the money
## ruler and the reward card are three of the four phases and none of them
## appears in it.

var _main
var _f := 0
var _at := 0
var _settle := 0
const STEP := 1.0 / 60.0


func _initialize() -> void:
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()


func _process(_d: float) -> bool:
	_f += 1
	if _f < 3:
		return false
	_settle += 1
	if _settle == 1:
		_pose(_at)
		return false
	if _settle < 5:
		return false
	_settle = 0
	root.get_texture().get_image().save_png("user://screen_%d.png" % _at)
	print("  screen %d" % _at)
	_at += 1
	if _at > 4:
		print("wrote %s" % OS.get_user_data_dir())
		_tear_down(_main)
		quit(0)
		return true
	return false


func _pose(i: int) -> void:
	var mem := {}
	match i:
		0:   # the home screen, with money to spend
			_main.freeze()
			_main.sim.cash = 2400.0
			_main._state.cash = 2400.0
			_main._set_phase(_main.Phase.HOME)
			_main._refresh_boosts()
			_main._sync()
		1:   # the money ruler, part way up, with a best to beat
			_main.freeze()
			for n in int(20.0 / STEP):
				Policies.steer(Policies.WEAVE, _main.sim, mem)
				_main.advance(STEP, STEP)
			_main._run_value = 18400.0
			_main._run_best = 12900.0
			_main._beat_best = true
			_main._ruler_t = 0.72
			_main._set_phase(_main.Phase.RULER)
			_main._ruler.queue_redraw()
		4:   # the pause panel, mid-run
			_main.freeze()
			var m2 := {}
			for n in int(6.0 / STEP):
				Policies.steer(Policies.WEAVE, _main.sim, m2)
				_main.advance(STEP, STEP)
			_main._open_pause()
		3:   # the shop, with money for the first rung
			_main.freeze()
			_main._state.owned = []
			_main._state.cash = 1500.0
			_main.sim.cash = 1500.0
			_main._set_phase(_main.Phase.SHOP)
		2:   # the reward card
			_main._run_value = 18400.0
			_main._beat_best = true
			_main._set_phase(_main.Phase.REWARD)


## TEAR THE SCENE DOWN BEFORE QUITTING.
##
## A `SceneTree` script that calls `quit()` with the game still in the tree exits
## with "N resources still in use" - the audio streams and the shader materials
## are still referenced by live nodes. It is only a shutdown message and it is
## still noise, and this repo treats an engine error as a failure precisely so
## that noise does not accumulate until nobody reads any of it.
func _tear_down(node: Node) -> void:
	if node == null:
		return
	if node.has_method("_sfx_stop"):
		node.call("_sfx_stop")
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
