extends SceneTree

## VISUAL REGRESSION: assertions about the rendered PICTURE, not about the model.
##
##   godot --path . --resolution 460x996 --script res://test/run_visual.gd
##
## **Not headless**: this is the only check here that needs a rendering context,
## which is the entire point. Everything else can tell you the numbers are right
## and nothing at all about whether the game is legible.
##
## Every visual bug this project has had so far was found by a person looking at
## a screenshot: station signs at eye height covering the road, candles rendering
## as solid black silhouettes, road stripes standing proud of the wax so a pool
## came out striped, and a pour so fat it lay across the runway like a baguette.
## All four are trivial to detect in pixels. A bug that can only be caught by
## looking is a bug that gets caught once and then comes back.
##
## THE THRESHOLDS ARE MEASURED, NOT CHOSEN. Run with `-- --report` to print the
## metrics for the current build and nothing else; the constants below are those
## numbers with headroom, and the comment on each says what it is defending
## against. A threshold picked by taste fails on the first honest change and
## teaches everyone to ignore it.

const TestHarnessScript := preload("res://test/harness.gd")

var _t: TestHarness
var _main
var _report := false
var _shots: Array[float] = []
var _at := 0
var _settle := 0
var _played := 0.0
var _metrics: Array[Dictionary] = []
const STEP := 1.0 / 60.0

## The horizon sits around row 430 at this camera. These bands are well clear of
## it in both directions, so they do not move when the camera lifts for a
## standing batch.
const SKY_BAND := Vector2i(90, 430)
const ROAD_BAND := Vector2i(560, 700)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--report":
			_report = true
	## A DENSE SWEEP, not a handful of chosen moments.
	##
	## Five sampled seconds missed the very bug this file was written for. The
	## station signs that filled half the frame only did so for about a second
	## after the batch passed under them, and none of the five landed in one -
	## with the signs put back at eye height the numbers barely moved, and the
	## check would have shipped looking like it worked.
	##
	## A frame costs a few milliseconds. Sample every second and a half across
	## the whole level, and judge the WORST frame: transient is exactly what a
	## chosen-moment check cannot see, and transient is most of what is wrong
	## with a runner.
	var t := 2.0
	while t < Tuning.level_seconds(1):
		_shots.append(t)
		t += 1.5

	_t = TestHarnessScript.new()
	var scene: PackedScene = load("res://src/game/main.tscn")
	_main = scene.instantiate()
	root.add_child(_main)
	_main.freeze()


func _process(_delta: float) -> bool:
	if _at >= _shots.size():
		_judge()
		return true

	if _settle == 0:
		var mem: Dictionary = _main.get_meta("vis_mem", {})
		while _played < _shots[_at] - STEP * 0.5:
			Policies.steer(Policies.WEAVE, _main.sim, mem)
			_main.advance(STEP, STEP)
			_played += STEP
		_main.set_meta("vis_mem", mem)

	_settle += 1
	if _settle < 4:
		return false
	_settle = 0

	_metrics.append(_measure(root.get_texture().get_image(), _played))
	_at += 1
	return false


## Everything read off one frame, in one pass per band.
func _measure(img: Image, t: float) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()

	var sky := _mean(img, SKY_BAND.x, SKY_BAND.y, w)
	var road := _mean(img, ROAD_BAND.x, ROAD_BAND.y, w)

	## How much of the upper band is still sky.
	##
	## This is the "can I see where I am going" check. The failure it exists for
	## is a station sign hung at the camera's own eye height: it slid across the
	## middle of the frame instead of sweeping out of the top, and covered the
	## road at the distance the player steers by.
	var sky_px := 0
	var sky_total := 0
	for y in range(SKY_BAND.x, SKY_BAND.y, 4):
		for x in range(0, w, 4):
			sky_total += 1
			if _is_sky(img.get_pixel(x, y)):
				sky_px += 1
	var sky_frac := float(sky_px) / float(maxi(1, sky_total))

	## How much of the lower half is nearly black.
	##
	## The candles came out as solid ink silhouettes for a whole build - an
	## outline hull that covered the object it was outlining - and the model was
	## perfectly happy the entire time.
	var dark := 0
	var dark_total := 0
	for y in range(int(h * 0.5), h, 4):
		for x in range(0, w, 4):
			dark_total += 1
			if _lightness(img.get_pixel(x, y)) < 0.16:
				dark += 1
	var dark_frac := float(dark) / float(maxi(1, dark_total))

	## SATURATED RUNS across several rows low in the frame.
	##
	## A wax pool is a CONTINUOUS SHEET, so a row crossing one should find one
	## run of saturated colour per half - two at most. When the road stripes
	## stood proud of the pool it rendered as wax alternating with road, and the
	## run count went into double figures.
	##
	## Counting colour CHANGES instead of runs was the first attempt and it was
	## useless: a marbled pool changes colour constantly, so the striped build
	## scored 49 against a healthy 45 and the check would have shipped looking
	## like it worked. What separates the two is not how often the colour
	## changes, it is how often it stops being wax and starts being road.
	var bands := 0
	for frac in [0.60, 0.66, 0.72, 0.78, 0.84]:
		var row := int(float(h) * frac)
		var n := 0
		var run := 0
		for x in range(0, w, 2):
			if _is_saturated(img.get_pixel(x, row)):
				run += 1
			else:
				if run >= 4:
					n += 1
				run = 0
		if run >= 4:
			n += 1
		bands = maxi(bands, n)

	return {
		"t": t,
		"sky_l": _lightness(sky),
		"road_l": _lightness(road),
		"separation": absf(_lightness(road) - _lightness(sky)),
		"sky_frac": sky_frac,
		"dark_frac": dark_frac,
		"bands": bands,
	}


func _judge() -> void:
	if _report:
		print("")
		print("  %6s %11s %9s %10s %6s"
			% ["t", "separation", "sky_frac", "dark_frac", "bands"])
		var worst := {"separation": 9.0, "sky_frac": 9.0, "dark_frac": -1.0, "bands": -1.0}
		for m in _metrics:
			print("  %6.1f %11.3f %9.3f %10.3f %6d"
				% [m.t, m.separation, m.sky_frac, m.dark_frac, m.bands])
			worst.separation = minf(worst.separation, m.separation)
			worst.sky_frac = minf(worst.sky_frac, m.sky_frac)
			worst.dark_frac = maxf(worst.dark_frac, m.dark_frac)
			worst.bands = maxf(worst.bands, float(m.bands))
		print("")
		print("  WORST over %d frames: separation %.3f  sky_frac %.3f  dark_frac %.3f  bands %d"
			% [_metrics.size(), worst.separation, worst.sky_frac, worst.dark_frac, int(worst.bands)])
		print("")
		_tear_down(_main)
		quit(0)
		return

	for m in _metrics:
		var at := "at t=%.1fs" % m.t
		_t.begin("visual > %s" % at)

		## WHAT THIS FILE CAN AND CANNOT SEE.
		##
		## Every threshold below was set from a 23-frame sweep of level one and
		## then checked against a deliberately broken build. Two candidate
		## metrics were thrown away because that check failed them:
		##
		##   - colour CHANGES across a row, meant to catch a wax pool rendering
		##     striped: 49 on the broken build against 45 on the good one.
		##   - saturated RUNS across five rows, the second attempt at the same
		##     thing: 8 against 7.
		##
		## Neither separates anything, and a guard that does not move when the
		## bug is present is worse than no guard - it is a green light nobody
		## has any reason to doubt. The striped pool and the sign hung at eye
		## height are both GEOMETRY, and geometry is exact in the model; they
		## are asserted in `run_smoke.gd`, where the answer is a number rather
		## than a shade.
		##
		## What frame statistics are good for is the whole picture going wrong
		## at once, which the model cannot see at all.

		## MEASURED: 0.084 on a good sweep, 0.008 when every material inks
		## itself. This is not the palette rule - that is a constant, and it is
		## checked as one in `run_smoke.gd`. It is "the frame still has range in
		## it", and it goes to nearly zero when everything turns one colour.
		_t.gt(m.separation, 0.03,
			"%s the frame has almost no range between its ground and its sky" % at)

		## MEASURED: 0.869 worst over the sweep. A coarse floor on being able to
		## see where you are going. It did NOT move for the sign bug, so it is
		## not the guard for that - see above.
		_t.gt(m.sky_frac, 0.72,
			"%s something very large is covering the upper half of the frame" % at)

		## MEASURED: 0.028 worst over the sweep, against 0.196 on a build where
		## every material inks itself - a seven-fold signal, and the only one of
		## these four candidates that clearly separated. This is the guard for
		## the build where the batch rendered as solid black silhouettes and
		## every model assertion stayed green.
		_t.lt(m.dark_frac, 0.10,
			"%s a tenth of the lower frame is nearly black - the usual cause is "
			% at + "an outline drawing over the thing it outlines")

	_finish()


func _mean(img: Image, y0: int, y1: int, w: int) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in range(y0, y1, 4):
		for x in range(0, w, 4):
			var p := img.get_pixel(x, y)
			r += p.r; g += p.g; b += p.b
			n += 1
	return Color(r / float(n), g / float(n), b / float(n))


func _lightness(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _dist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


## Wax, not road and not sky: a strong hue. The road is near-white (chroma
## 0.05) and the lane stripes are the palest lavender (0.13), so the bar sits
## well above both.
func _is_saturated(c: Color) -> bool:
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	return mx - mn > 0.22 and not _is_sky(c)


func _is_sky(c: Color) -> bool:
	# The gradient runs from SKY_TOP to SKY, so "sky" is a band of blues rather
	# than one colour: blue dominant, green well above red.
	return c.b > 0.55 and c.b > c.r + 0.25 and c.g > c.r


func _finish() -> void:
	print("")
	if _t.failures.is_empty():
		print("  visual: %d assertions, all passing" % _t.checks)
		_tear_down(_main)
		quit(0)
		return
	for f in _t.failures:
		print("  FAIL  %s" % f)
	print("")
	print("  visual: %d assertions, %d FAILED" % [_t.checks, _t.failures.size()])
	quit(1)


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
