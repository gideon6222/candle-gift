extends SceneTree

## Smoke test: boots the real scene and plays it.
##
##   godot --headless --script res://test/run_smoke.gd
##
## The pure tests in run_tests.gd cannot see a wiring bug - a scene that fails
## to build, a node that is never added, a render path that stopped being
## flushed, a HUD reading a field that no longer exists. Those only show up when
## something actually instantiates the game.
##
## The load-bearing assertions are the flush checks: **the number of instances
## drawn must match the number of things that exist.** A subsystem that renders
## nothing and a subsystem that does not exist look identical from outside, and
## that exact bug has already cost a full tuning pass on another game here.

var _t := TestHarness.new()


func _initialize() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	_t.begin("smoke > the scene loads")
	_t.ok(scene != null, "main.tscn failed to load")
	if scene == null:
		_finish()
		return

	var main = scene.instantiate()
	root.add_child(main)

	# Freeze first, then step. Real frames run between a scene loading and a
	# harness taking over, so without this every number would move with the
	# speed of the machine - and `_ready` has not fired yet either, because
	# add_child() during SceneTree._initialize() defers it to the first
	# processed frame. freeze() boots the scene explicitly.
	main.freeze()

	_t.begin("smoke > the scene builds its world")
	_t.ok(main.sim != null, "Sim was never created")
	_t.ok(main.get_node_or_null("Road") != null, "the road is missing from the scene")

	main.advance(12.0)
	var s: Dictionary = main.sim.state()

	_t.begin("smoke > twelve seconds of play happened")
	_t.gt(s["distance"], 60.0, "the batch barely moved in twelve seconds")
	_t.gt(float(s["loose"]) + float(s["obstacles"]), 0.0, "nothing was spawned on the track")

	_check_the_batch_is_drawn(main)
	_check_the_world_is_drawn(main)
	_check_both_forms_draw(main)
	_check_the_hud(main)
	_check_the_controls_are_anchored(main)
	_check_the_level_can_be_left(main)

	_finish()


## Every band of every candle has to reach a MultiMesh.
##
## This is the assertion that catches a lost flush, and it is checked in BOTH
## forms further down - because the flush that goes missing is the one in the
## form nobody tested.
func _check_the_batch_is_drawn(main) -> void:
	_t.begin("smoke > every candle is drawn")
	var want := 0
	for c in main.sim.batch:
		want += c.layers.size()
	var drawn := 0
	for mm in main._bands:
		drawn += mm.multimesh.visible_instance_count
	_t.gt(float(want), 0.0, "the batch is empty, so this proves nothing")
	_t.eq(drawn, want, "bands drawn does not match the recipes in the batch")
	_t.eq(main._wicks.multimesh.visible_instance_count, main.sim.count(),
		"one wick per candle")


func _check_the_world_is_drawn(main) -> void:
	_t.begin("smoke > the world is drawn")
	_t.eq(main._loose.multimesh.visible_instance_count, _live(main.sim.loose),
		"loose candles drawn do not match the model")
	_t.eq(main._notes.multimesh.visible_instance_count, _live(main.sim.notes),
		"money drawn does not match the model")
	_t.gt(float(main._stripes.multimesh.visible_instance_count), 0.0,
		"the lane stripes are not being drawn, so there is no sense of speed")
	_t.gt(float(main._towers.multimesh.visible_instance_count), 0.0,
		"the skyline is not being drawn")


## The batch has TWO FORMS and both have to draw.
##
## `standing` is simulation state - the ROTATE wall sets it - and the renderer
## blends between a loaf lying across the lane and a row of upright candles. A
## flush that only works in one of them fails completely silently in the other.
func _check_both_forms_draw(main) -> void:
	_t.begin("smoke > both forms of the batch draw")
	for standing in [false, true]:
		main.sim.standing = standing
		main._stand = 1.0 if standing else 0.0
		main.advance(1.0 / 60.0, 1.0 / 60.0)
		var want := 0
		for c in main.sim.batch:
			want += c.layers.size()
		var drawn := 0
		for mm in main._bands:
			drawn += mm.multimesh.visible_instance_count
		_t.eq(drawn, want, "bands are not drawn when standing=%s" % standing)


func _check_the_hud(main) -> void:
	## THREE THINGS: the gear, the level and the money. The reference has no
	## candle counter, no running value and no progress bar, and every one of
	## those was the sibling build's own invention.
	_t.begin("smoke > the HUD says what the run says")
	_t.ok(main._level_pill.text.contains(str(main.sim.level)),
		"the level pill disagrees with the run")
	_t.ok(main._money_pill.text.contains("$"), "the money pill is not being written")


## The controls must be ANCHORED to the viewport, never placed at a literal
## coordinate.
##
## A structural assertion rather than a behavioural one, because the bug it
## guards against is invisible at the size the tests run. The project stretches
## with `aspect = "expand"`, which keeps the base WIDTH and extends the HEIGHT,
## so on a 19.5:9 phone the canvas is about 1080x2340 while the base is
## 1080x1920. Controls laid out against the literal 1920 drew hundreds of pixels
## above where they belonged, and the report was "the icons are about half an
## inch too high".
##
## **A headless run uses the base size, where the wrong layout and the right one
## are identical** - so no screenshot or coordinate check taken here could ever
## catch it. What CAN be checked is the property that makes it impossible.
func _check_the_controls_are_anchored(main) -> void:
	_t.begin("smoke > the controls are anchored, not placed")
	var ui: Control = main._ui
	_t.eq(ui.anchor_right, 1.0, "the UI root does not span the viewport width")
	_t.eq(ui.anchor_bottom, 1.0, "the UI root does not span the viewport height")

	var gear: Control = main._gear
	_t.ok(gear.gui_input.get_connections().size() > 0,
		"the gear does not handle its own input, so its hit box is a second source of truth")
	_t.eq(gear.mouse_filter, Control.MOUSE_FILTER_STOP,
		"the gear does not consume its own touches, so one gesture drives two things")

	## Walk UP from the label to whatever is anchored, rather than checking the
	## label itself.
	##
	## The pill became a gold panel with the label inside it, so the label is
	## laid out by its container and its own anchors are meaningless - the
	## check went red for a change that was entirely correct. What the rule
	## actually says is that the pill resolves from the viewport EDGE, and that
	## is true of whichever ancestor carries the anchor. Asserting it of one
	## named node was asserting the shape of the scene, not the property.
	var money: Control = main._money_pill
	while money != null and money.anchor_right != 1.0 and money.get_parent() is Control:
		money = money.get_parent()
	_t.eq(money.anchor_right, 1.0,
		"the money pill is not anchored to the right edge - it will drift on a wide screen")

	var pill_panel: Node = main._money_pill.get_parent().get_parent()
	_t.ok(pill_panel is PanelContainer,
		"the money pill has no panel behind it, so it is white text on the sky")
	_t.ok(pill_panel.get_theme_stylebox("panel") != null,
		"the money pill panel has no stylebox, so it is not gold")
	_t.ok(main._font != null,
		"the HUD font did not load, so every screen falls back to the engine default")


## A finished level must start the next one.
##
## The assertion an earlier version of this template did not have, and the one
## that would have caught the first bug a game built from it shipped: `over`
## went true at the end of a level, `advance()` returned early from then on, and
## the game froze with a live HUD.
##
## Every other test in the suite plays a level and reads the state at the END,
## which is the exact instant that freeze begins. **A suite that always stops
## where the content stops cannot see past the end of the content**, so this one
## deliberately drives THROUGH the boundary - and through the real scene, since
## the missing code was in the renderer's handler and not in Sim.
func _check_the_level_can_be_left(main) -> void:
	_t.begin("smoke > a finished level starts the next one")
	main.freeze()
	var guard := 0
	while not main.sim.over and guard < 12000:
		main.advance(1.0 / 60.0, 1.0 / 60.0)
		guard += 1
	_t.eq(main.sim.over, true, "the level never ended")
	_t.eq(main.sim.standing, true,
		"the level ended without crossing the ROTATE wall, which spans the track")

	var level: int = main.sim.level
	main.advance(main.INTERLUDE_SECONDS + 0.5, 1.0 / 60.0)
	_t.eq(main.sim.over, false,
		"the game is still frozen after the interlude - this is the bug that shipped")
	_t.eq(main.sim.level, level + 1, "finishing a level did not start the next one")
	_t.eq(main.sim.standing, false, "the next level did not start lying down again")

	# And it has to actually play on the other side.
	var before: float = main.sim.distance
	main.advance(1.0, 1.0 / 60.0)
	_t.gt(main.sim.distance, before, "the next level does not advance when the frame loop runs")


func _live(items: Array[Dictionary]) -> int:
	var n := 0
	for i in items:
		if not i.taken:
			n += 1
	return n


func _finish() -> void:
	print("")
	if _t.failures.is_empty():
		print("  smoke: %d assertions, all passing" % _t.checks)
		quit(0)
		return
	for f in _t.failures:
		print("  FAIL  %s" % f)
	print("")
	print("  smoke: %d assertions, %d FAILED" % [_t.checks, _t.failures.size()])
	quit(1)
