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
var _main
var _frames := 0
var _started := false


## THE CHECKS RUN AFTER REAL FRAMES, not inside `_initialize`.
##
## Control layout is resolved during a frame. With everything done in
## `_initialize` no frame ever runs, every Control keeps a zero-size rect at the
## origin, and a test that pushes a click at a button's centre clicks nothing at
## all - silently, because a click that hits nothing is not an error.
##
## That is not a testing detail, it is the difference between asserting a button
## WORKS and asserting a button EXISTS. Three frames is enough for the layout to
## settle; `frozen` keeps the simulation still while they pass.
func _initialize() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	_t.begin("smoke > the scene loads")
	_t.ok(scene != null, "main.tscn failed to load")
	if scene == null:
		_finish()
		return

	_main = scene.instantiate()
	root.add_child(_main)

	# Freeze first, then step. Real frames run between a scene loading and a
	# harness taking over, so without this every number would move with the
	# speed of the machine - and `_ready` has not fired yet either, because
	# add_child() during SceneTree._initialize() defers it to the first
	# processed frame. freeze() boots the scene explicitly.
	_main.freeze()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	if not _started:
		_started = true
		## `_run` is a COROUTINE and quits the tree itself when it is done.
		##
		## It has to be, because showing a screen is not the same as laying it
		## out: a hidden Control is not laid out at all, so the frame after it
		## becomes visible is the first one where its children have real rects.
		## Without a frame in between, a test that presses a button inside a
		## freshly-opened panel presses empty space - and hitting nothing is not
		## an error, so it passes for the wrong reason.
		_run(_main)
	return false


## Let the layout catch up. Two frames, because a container that resizes its
## children can take one frame to size itself and another to place them.
func _settle() -> void:
	await process_frame
	await process_frame


func _run(main) -> void:
	_t.begin("smoke > the scene builds its world")
	_t.ok(main.sim != null, "Sim was never created")
	_t.ok(main.get_node_or_null("Road") != null, "the road is missing from the scene")

	## The layout that the frames above were for. Without a resolved rect every
	## input-driven assertion below is a click into empty space that passes for
	## the wrong reason.
	_t.gt(main._ui.size.x, 0.0, "the UI root has no size, so no control can be clicked")
	_t.gt(main._reward_take.get_global_rect().size.x, 0.0,
		"a button has no rect, so pressing it would hit nothing")

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
	_check_the_palette(main)
	_check_the_pool_clears_the_stripes(main)
	_check_no_gantry_is_left_behind(main)
	_check_a_tap_on_a_card_does_not_start_the_run(main)
	_check_progress_is_saved(main)
	await _check_the_shop_sells_shops(main)

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
## THE PALETTE, as constants, before anything is drawn.
##
## Workshop 2 of the last game on these notes shipped as a pink runway under a
## pink sky, and the track dissolved into the backdrop at about twenty metres -
## which is the distance you steer by. It is a property of two colours and needs
## no rendering to check, so it is checked here rather than in `run_visual.gd`,
## where the same question comes out as a noisy shade that depends on whether
## the sampled band happened to land in a wax pool.
##
## A MAGNITUDE, not a direction. This game is a pale road under a saturated sky,
## the opposite way round from the last one and equally legible.
func _check_the_palette(main) -> void:
	_t.begin("smoke > the road and the sky cannot be confused")
	var consts: Dictionary = main.get_script().get_script_constant_map()
	var road: Color = consts["ROAD"]
	var sky: Color = consts["SKY"]
	var sky_top: Color = consts["SKY_TOP"]
	_t.gt(absf(_lightness(road) - _lightness(sky)), 0.25,
		"the road and the sky are too close in lightness")
	_t.gt(absf(_lightness(road) - _lightness(sky_top)), 0.25,
		"the road and the top of the sky are too close in lightness")
	## The gradient may go darker toward the top and nowhere else: fading toward
	## white at the horizon is what puts a white runway against a near-white
	## backdrop.
	_t.lt(_lightness(sky_top), _lightness(sky),
		"the sky gets LIGHTER toward the top, so it approaches the road colour")


## The wax has to sit above the lane stripes, and by more than nothing.
##
## The stripes are boxes with a height, not decals: their tops are at
## y = position + height/2, and a pool laid below that has them standing PROUD
## of it. It renders as wax with white rungs across it, which reads as a
## transparency bug or as z-fighting and is neither.
##
## Checked as a number rather than by looking, because looking is what missed it
## for a whole build - and because `run_visual.gd` was given two different
## chances to catch it in pixels and could not separate it from a marbled pool.
func _check_the_pool_clears_the_stripes(main) -> void:
	_t.begin("smoke > the wax clears the lane stripes")
	var stripe_mesh: BoxMesh = main._stripes.multimesh.mesh
	var stripe_top := 0.02 + stripe_mesh.size.y * 0.5
	var pools := 0
	for rig in main._rigs:
		for h in rig.get_meta("halves"):
			var liq: MeshInstance3D = h.liquid
			pools += 1
			_t.gt(liq.position.y, stripe_top + 0.02,
				"a wax pool at y=%.3f does not clear the stripe tops at y=%.3f"
					% [liq.position.y, stripe_top])
	_t.gt(float(pools), 0.0, "no wax pools were found at all")


## No station gantry may be drawn CLOSE TO THE LENS.
##
## The pool and the gantry need different cull distances and shared one for a
## build. The pool is ground and has to outlast the batch standing in it; the
## gantry is overhead and has to go once it is passed, or a sign a few metres
## off the camera covers half the road.
##
## Stated as a distance from the CAMERA, not from the batch, because that is
## what the rule is actually about and the camera sits eleven metres further
## back. Written as "nothing behind the batch" first, this failed on a
## deliberate one-metre grace that stops the gantry popping out exactly as you
## cross it - a gantry a metre behind the batch is still eleven metres from the
## lens and completely harmless. The bug being guarded against culled at five.
##
## SIX METRES is the bar: a 2.3 m sign at that range subtends about a fifth of
## the frame width, and it gets worse fast as it closes.
##
## This is the assertion `run_visual.gd` could not make. With the single cull
## put back, the fraction of the upper frame that is still sky went from 0.869
## to 0.826 - present, and far too small to set a threshold on. Here it is exact.
func _check_no_gantry_is_left_behind(main) -> void:
	_t.begin("smoke > no gantry is drawn close to the lens")
	main.freeze()
	var mem := {}
	var nearest := 1e9
	var seen := 0
	for i in 60 * 12:
		Policies.steer(Policies.WEAVE, main.sim, mem)
		main.advance(1.0 / 60.0, 1.0 / 60.0)
		for rig in main._rigs:
			if not rig.visible:
				continue
			for h in rig.get_meta("halves"):
				var furn: Node3D = h.furn
				if not furn.visible:
					continue
				seen += 1
				nearest = minf(nearest, rig.position.z - main._cam_z)
	_t.gt(float(seen), 0.0,
		"no gantry was drawn at all in twelve seconds, so this proves nothing")
	_t.gt(nearest, 6.0,
		"a station gantry was drawn %.1f m from the camera - at that range its "
			% nearest + "sign covers a fifth of the frame")


## A FINISHED LEVEL GOES RULER -> REWARD -> HOME -> NEXT RUN, and every step of
## that is driven here through the same controls a thumb would use.
##
## The bug this replaced a simpler test for: `over` went true at the end of the
## first level, `advance()` returned early from then on, and the game sat frozen
## with a live HUD - which to the person holding the phone is a crash. Now that
## there are screens in between, "the next level starts" is four transitions and
## any one of them can be the one that never fires.
func _check_the_level_can_be_left(main) -> void:
	_t.begin("smoke > a finished level goes through the screens to the next one")
	main.freeze()
	var guard := 0
	while not main.sim.over and guard < 12000:
		main.advance(1.0 / 60.0, 1.0 / 60.0)
		guard += 1
	_t.eq(main.sim.over, true, "the level never ended")
	_t.eq(main.sim.standing, true,
		"the level ended without crossing the ROTATE wall, which spans the track")
	_t.eq(main._phase, main.Phase.RULER, "finishing a level did not show the money ruler")
	_t.ok(main._ruler.visible, "the ruler is the phase but is not visible")
	_t.ok(not main._reward.visible, "the reward screen is up during the ruler")

	## THE RULER MUST NOT ADVANCE THE WORLD. It is a summary of a run that has
	## finished; a simulation still running under it would keep banking money
	## while the player watches the total they already earned climb.
	var frozen_at: float = main.sim.distance
	main.advance(main.RULER_SECONDS + 0.2, 1.0 / 60.0)
	_t.eq(main.sim.distance, frozen_at, "the simulation kept running under the ruler")
	_t.eq(main._phase, main.Phase.REWARD, "the ruler never handed over to the reward screen")

	var level: int = main.sim.level
	var cash_before: float = main.sim.cash
	var earned: float = main._run_value
	_t.gt(earned, 0.0, "the run was worth nothing, so banking it proves nothing")

	_press(main._reward_take)
	_t.eq(main._phase, main.Phase.HOME, "taking the reward did not return to the home screen")
	_t.approx(main.sim.cash, cash_before + earned, 0.01,
		"taking the reward did not bank the money")
	_t.eq(main.sim.level, level + 1, "taking the reward did not start the next level")
	_t.eq(main.sim.standing, false, "the next level did not start lying down again")
	_t.ok(main._home.visible, "the home screen is the phase but is not visible")

	## HOME IS THE GAME WITH THE SIMULATION NOT YET RUNNING. The world is drawn -
	## the level behind the cards is the one about to be played - but nothing
	## moves until the swipe.
	var home_at: float = main.sim.distance
	main.advance(0.5, 1.0 / 60.0)
	_t.eq(main.sim.distance, home_at, "the world is running while the home screen is up")

	_swipe(main, 30.0)
	_t.eq(main._phase, main.Phase.RUN, "a swipe on the world did not start the run")
	main.advance(0.5, 1.0 / 60.0)
	_t.gt(main.sim.distance, home_at, "the run started but the world does not advance")


## THE BUG THAT SHIPPED TWICE on the last game: a control drawn over the world
## that the world's own input handler also answers, so tapping "buy" started the
## run instead of buying anything.
##
## Godot makes this structurally harder - steering lives in `_unhandled_input`,
## so an event a control consumes never reaches it - but "harder" is not
## "cannot". The way it comes back is a container with the wrong mouse filter
## swallowing the tap before the button sees it, or a button that never got
## MOUSE_FILTER_STOP. Both are exactly what this asserts.
func _check_a_tap_on_a_card_does_not_start_the_run(main) -> void:
	_t.begin("smoke > the boost cards can be tapped without starting the run")
	main.freeze()
	main._set_phase(main.Phase.HOME)
	main.sim.cash = 5000.0
	main._state.cash = 5000.0
	main._refresh_boosts()

	_t.eq(main._home.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the home container swallows input, so the swipe that starts a run cannot reach the world")
	for b in [main._boost_candle, main._boost_cash, main._reward_take]:
		_t.eq(b.mouse_filter, Control.MOUSE_FILTER_STOP,
			"a button does not consume its own touches, so one gesture drives two things")

	var before: int = main.sim.boost_candles
	_press(main._boost_candle)
	_t.eq(main.sim.boost_candles, before + 1, "the CANDLE card did not buy anything")
	_t.eq(main._phase, main.Phase.HOME, "buying a boost started the run")
	_t.approx(main.sim.cash, 4500.0, 0.01, "the CANDLE card did not charge for itself")
	_t.eq(main.sim.count(), Tuning.START_CANDLES + 1,
		"the extra candle was bought but the batch does not have it - the level was "
		+ "not laid out again")

	_press(main._boost_cash)
	_t.approx(main.sim.boost_cash, 1.5, 0.001, "the CASH card did not apply its bonus")
	_t.eq(main._phase, main.Phase.HOME, "buying a boost started the run")

	## And a card you cannot afford does nothing at all.
	main.sim.cash = 0.0
	main._state.cash = 0.0
	main.sim.boost_candles = 0
	main._refresh_boosts()
	_press(main._boost_candle)
	_t.eq(main.sim.boost_candles, 0, "a boost was bought with no money")
	_t.approx(main.sim.cash, 0.0, 0.01, "money went negative buying a boost")


## Progress has to survive being put down.
func _check_progress_is_saved(main) -> void:
	_t.begin("smoke > progress survives a reload")
	Save._reset_latch_for_tests()
	main.freeze()
	main._state.cash = 777.0
	main._state.level = 4
	main._state.best = 12345.0
	main._state.owned = [Shops.ONLINE, Shops.BOUTIQUE]
	Save.store(main._state)

	var reloaded := Save.load_state()
	_t.approx(float(reloaded.cash), 777.0, 0.01, "cash did not survive")
	_t.eq(int(reloaded.level), 4, "level did not survive")
	_t.eq(reloaded.owned.size(), 2, "the shops owned did not survive")

	## `sim.restart` knows nothing about the save, so anything that restarts a
	## level has to reapply it. A level restarted without that silently drops
	## every shop the player owns, which looks like the shop not working.
	main._state = reloaded
	main.sim.restart(4)
	main._apply_save_to_sim()
	_t.eq(main.sim.press_level, 1, "restarting a level dropped a bought shop")
	_t.eq(main.sim.earn_level, 1, "restarting a level dropped a bought shop")


## THE SHOP SELLS SHOPS, and the ladder is the point of it.
##
## Driven through the real buttons, because the model is already covered by
## `test_shops.gd` - what this adds is that the screen is reachable, that its
## rows are wired to the right ids, and that a disabled row cannot be bought by
## tapping it anyway.
func _check_the_shop_sells_shops(main) -> void:
	_t.begin("smoke > the shop sells shops")
	Save._reset_latch_for_tests()
	main.freeze()
	main._state.owned = []
	main._state.cash = 1500.0
	main.sim.cash = 1500.0
	main._set_phase(main.Phase.SHOP)
	await _settle()

	_t.ok(main._shop.visible, "the shop is the phase but is not visible")
	_t.eq(main._shop_rows.get_child_count(), Shops.ALL.size(),
		"the shop does not have a row for every shop in the ladder")

	var rows: Array = main._shop_rows.get_children()
	var first: Button = rows[0].get_meta("buy")
	var third: Button = rows[2].get_meta("buy")
	_t.eq(first.disabled, false, "the first rung is not buyable with the money for it")
	_t.eq(third.disabled, true, "a rung further up the ladder was buyable")

	## TAPPING A DISABLED ROW MUST DO NOTHING. A disabled Button swallows the
	## press in Godot, but "the engine does it for us" is exactly the assumption
	## that stops being true the day someone styles the row as a Panel with a
	## click handler instead.
	var cash_before: float = main.sim.cash
	_press(third)
	_t.approx(main.sim.cash, cash_before, 0.01, "tapping a locked shop charged for it")
	_t.eq(main._state.owned.size(), 0, "tapping a locked shop bought it")

	_press(first)
	_t.eq(Shops.owns(main._state.owned, Shops.ONLINE), true,
		"buying the first shop did not record it")
	_t.approx(main.sim.cash, 500.0, 0.01, "buying a shop did not charge the right price")
	_t.eq(main.sim.earn_level, 1, "buying the online shop did not reach the simulation")
	_t.eq(first.disabled, true, "a shop just bought is still for sale")
	_t.eq(first.text, "OWNED", "a shop just bought does not say so")

	## And it is on disk, not just in memory.
	var reloaded := Save.load_state()
	_t.eq(Shops.owns(reloaded.owned, Shops.ONLINE), true, "the purchase was not saved")

	## The next rung opens up once there is money for it.
	main.sim.cash = 9000.0
	main._state.cash = 9000.0
	main._refresh_shop()
	var second: Button = rows[1].get_meta("buy")
	_t.eq(second.disabled, false, "the next rung did not open once it was affordable")

	_t.begin("smoke > the shop scrolls")
	## THE LAST GAME SHIPPED A WORKSHOP THAT WOULD NOT SCROLL, because the
	## world's drag handler answered the gesture and steered instead. Steering
	## lives in `_unhandled_input` here, so anything this container consumes
	## never reaches it - but that only helps if the container is reachable.
	_t.eq(main._shop_scroll.mouse_filter, Control.MOUSE_FILTER_STOP,
		"the shop's scroll container does not take input, so it cannot scroll")

	## THE VIEW IS SHRUNK FOR THIS CHECK, deliberately.
	##
	## Seven rows fit on a phone, so at its real size there is nothing to
	## scroll and the check would pass without exercising anything. Asserting a
	## behaviour that the current content cannot reach is a green light that
	## goes out the day an eighth shop is added - which is precisely when it
	## would matter. So the view is made too small on purpose and the gesture
	## is tested for real.
	main._shop_scroll.anchor_bottom = 0.0
	main._shop_scroll.offset_bottom = 630.0
	await _settle()
	_t.gt(main._shop_rows.size.y, main._shop_scroll.size.y,
		"the view was shrunk and the rows still fit, so this proves nothing")

	var before: int = main._shop_scroll.scroll_vertical
	_drag_touch(main._shop_scroll, Vector2(0, -320))
	await _settle()
	_t.gt(float(main._shop_scroll.scroll_vertical), float(before),
		"dragging the shop did not scroll it")
	_t.eq(main._phase, main.Phase.SHOP, "dragging inside the shop left the shop")

	main._shop_scroll.anchor_bottom = 1.0
	main._shop_scroll.offset_bottom = -220.0
	await _settle()

	var back: Button = main._shop.get_child(main._shop.get_child_count() - 1)
	_press(back)
	_t.eq(main._phase, main.Phase.HOME, "leaving the shop did not go back to the home screen")


## Driving a control the way a thumb does, rather than calling its handler.
##
## `emit_signal("pressed")` would pass even if the button were off-screen, behind
## something, or not accepting input at all - which is most of what can go wrong
## with a control. This goes through the viewport so the hit test is real.
func _press(b: Button) -> void:
	var at := b.get_global_rect().get_center()
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		## `in_local_coords = true`, and it is the whole trick.
		## Without it the viewport transforms the position by its own canvas
		## transform and the click lands nowhere - and a click that hits nothing
		## is NOT an error, so the test goes green having proved nothing. Measured
		## on a bare Button under the root: zero presses without it, one with.
		b.get_viewport().push_input(e, true)


## A FINGER DRAG, not a mouse wheel.
##
## The wheel would scroll a ScrollContainer and prove nothing about a phone. The
## gesture that failed on the last game was a drag, and a drag is what has to be
## answered by the container rather than by the world behind it.
func _drag_touch(c: Control, delta: Vector2) -> void:
	var vp := c.get_viewport()
	var at: Vector2 = c.get_global_rect().get_center()
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = at
	vp.push_input(down, true)
	for i in 8:
		var step := delta / 8.0
		var mv := InputEventScreenDrag.new()
		mv.position = at + step * float(i + 1)
		mv.relative = step
		vp.push_input(mv, true)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = at + delta
	vp.push_input(up, true)


func _swipe(main, dx: float) -> void:
	var vp: Viewport = main.get_viewport()
	var at: Vector2 = vp.get_visible_rect().size * 0.5
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	vp.push_input(down, true)
	var move := InputEventMouseMotion.new()
	move.position = at + Vector2(dx, 0)
	move.relative = Vector2(dx, 0)
	vp.push_input(move, true)


func _lightness(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


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
