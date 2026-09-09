extends Node3D

## The shell. Reads `Sim` and draws it; never decides anything.
##
## The scene file next to this is four lines on purpose - one node with this
## script. Everything visible is built here in code: a procedural game's world
## is built at runtime anyway, so an editor layout would be a second source of
## truth, and building it here keeps the whole project reviewable as text.
##
## The look is off `REFERENCE.md`: a white runway with pale lavender stripes and
## lilac rails under a FLAT bright cyan sky, hot-pink pill signs on thin dark
## curved arms, candy-coloured wax in tubs that stand proud of the road, and a
## skyline of pale stacked-cylinder candle towers well below the track.

const POOL := 64                  ## per world entity kind
const BANDS := Tuning.MAX_CANDLES * Tuning.MAX_LAYERS
const STATION_SLOTS := 3          ## pooled station rigs; the horizon holds this many

var sim: Sim

var _cam: Camera3D
var _road: MeshInstance3D
var _rail_l: MeshInstance3D
var _rail_r: MeshInstance3D

## One MultiMesh per mould shape. Only the shape currently being pressed is ever
## non-empty, so switching press mid-run costs nothing and the candles on screen
## are literally the cross-section the machine stamps.
var _bands: Array[MultiMeshInstance3D] = []
var _wicks: MultiMeshInstance3D
var _ribbons: MultiMeshInstance3D
var _bows: MultiMeshInstance3D
var _sparks: MultiMeshInstance3D

var _stripes: MultiMeshInstance3D
var _loose: MultiMeshInstance3D
var _loose_tips: MultiMeshInstance3D
var _notes: MultiMeshInstance3D
var _note_holes: MultiMeshInstance3D
var _barriers: MultiMeshInstance3D
var _spikes: MultiMeshInstance3D
var _bar_marks: MultiMeshInstance3D
var _sweepers: MultiMeshInstance3D
var _sweep_tips: MultiMeshInstance3D
var _towers: MultiMeshInstance3D
var _tower_tips: MultiMeshInstance3D
var _posts: MultiMeshInstance3D

var _rigs: Array[Node3D] = []

var _ui: Control
var _level_pill: Label
var _money_pill: Label
var _gear: Control
var _toast: Label
var _toast_t := 0.0

## 0 lying flat, 1 stood up. Eased, because the moment the batch rears up is the
## most dramatic thing in a run and snapping it wastes it. **Nothing outside
## this file reads it** - the simulation's `standing` is the truth, and this is
## only how far through the animation the drawing is.
var _stand := 0.0

## Where the camera is, so a station behind it can be culled. Culling on the
## BATCH's position is not enough: the camera sits fifteen-odd metres back,
## so a station just behind the batch is still several metres in FRONT of
## the lens, and its sign fills the bottom of the screen from a metre away.
var _cam_z := 0.0

var _dragging := false
var _booted := false
var _interlude := 0.0

## Set by the headless harness. When true the frame loop does not step the sim,
## so `advance()` is the only thing moving time and results do not depend on how
## fast the machine boots.
var frozen := false

const INTERLUDE_SECONDS := 2.4

# --- the palette, in one place -------------------------------------------
const SKY := Color(0.071, 0.702, 0.933)
const ROAD := Color(0.949, 0.933, 0.984)
const STRIPE := Color(0.878, 0.831, 0.957)
const RAIL := Color(0.690, 0.478, 0.894)
const CORAL := Color(0.941, 0.290, 0.235)
const CORAL_LIGHT := Color(0.957, 0.400, 0.353)
const SALMON := Color(1.000, 0.478, 0.361)
const NAVY := Color(0.118, 0.227, 0.427)
const GOLD := Color(1.000, 0.776, 0.102)
const PALE := Color(1.000, 0.957, 0.847)
const GREEN := Color(0.122, 0.659, 0.302)
const PINK := Color(0.910, 0.133, 0.431)
const CHROME := Color(0.933, 0.953, 0.973)
const TOWER := Color(0.875, 0.941, 1.000)


func _ready() -> void:
	_ensure_booted()


## Building the world is idempotent and callable before the first frame.
##
## `_ready` does not run at `add_child()` - it is deferred to the first
## processed frame - so a headless harness that adds this node and immediately
## calls `advance()` finds `sim` still null. The fix is a guard rather than a
## rule about call order, because a rule about call order is something every
## future test has to remember.
func _ensure_booted() -> void:
	if _booted:
		return
	_booted = true
	sim = Sim.new()
	_build_world()
	sim.level_finished.connect(_on_level_finished)
	sim.stood_up.connect(_on_stood_up)
	sim.hit_obstacle.connect(_on_hit)
	_sync()


# --- world ----------------------------------------------------------------

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	## FLAT, and never fading toward white at the horizon. A gradient sky put a
	## white runway against a near-white backdrop at exactly the distance the
	## player steers by, which is the same failure as a pink road under a pink
	## sky: the track dissolves about twenty metres out.
	e.background_color = SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.80, 0.86, 0.95)
	e.ambient_light_energy = 0.85
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -34, 0)
	sun.light_energy = 1.25
	add_child(sun)

	_cam = Camera3D.new()
	_cam.fov = 58
	_cam.far = 420
	add_child(_cam)

	_road = MeshInstance3D.new()
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(Tuning.ROAD_HALF_WIDTH * 2.0, 1.2, 1200.0)
	_road.mesh = road_mesh
	_road.material_override = _mat(ROAD)
	_road.position.y = -0.6
	_road.name = "Road"
	add_child(_road)

	_rail_l = _rail(-1)
	_rail_r = _rail(1)

	# lane stripes: the main sense of speed
	_stripes = _mm(_box(Tuning.ROAD_HALF_WIDTH * 2.0, 0.06, 1.1), STRIPE, 64)

	# the batch
	for m in Wax.MOULDS.size():
		var mm := _mm(_mould_mesh(m), Color.WHITE, BANDS, true)
		_bands.append(mm)
	_wicks = _mm(_cyl(0.16, 0.16, 1.0, 7), GOLD, Tuning.MAX_CANDLES)
	_ribbons = _mm(_box(1.0, 1.0, 1.0), PINK, Tuning.MAX_CANDLES, true)
	_bows = _mm(_box(1.0, 1.0, 1.0), GOLD, Tuning.MAX_CANDLES, true)
	_sparks = _mm(_box(0.10, 0.10, 0.10), Color.WHITE, Tuning.MAX_CANDLES)

	# pickups
	_loose = _mm(_cyl(0.24, 0.24, 1.0, 10), Color(1.0, 0.776, 0.102), POOL)
	_loose_tips = _mm(_cyl(0.02, 0.20, 0.34, 8), PALE, POOL)
	_notes = _mm(_box(1.15, 0.09, 0.60), GREEN, POOL)
	_note_holes = _mm(_cyl(0.10, 0.10, 0.16, 8), Color.WHITE, POOL)

	# obstacles
	_barriers = _mm(_box(2.0, 0.52, 0.42), CORAL, POOL)
	_spikes = _mm(_cyl(0.0, 0.50, 0.80, 4), CORAL_LIGHT, POOL * 2)
	_bar_marks = _mm(_box(0.62, 0.13, 0.09), Color.WHITE, POOL * 3)
	_sweepers = _mm(_box(3.4, 0.30, 0.34), SALMON, POOL)
	_sweep_tips = _mm(_cyl(0.0, 0.44, 0.90, 4), NAVY, POOL)
	_posts = _mm(_box(0.40, 3.4, 0.40), Color(0.561, 0.510, 0.600), POOL)

	# scenery: pale stacked-cylinder candle towers, well below the track
	_towers = _mm(_cyl(1.0, 1.0, 1.0, 10), TOWER, POOL * 2)
	_tower_tips = _mm(_cyl(0.0, 0.62, 1.3, 8), GOLD, POOL)

	for i in STATION_SLOTS:
		_rigs.append(_make_rig())

	_build_hud()


func _rail(side: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _box(0.5, 0.6, 1200.0)
	m.material_override = _mat(RAIL)
	m.position = Vector3(float(side) * (Tuning.ROAD_HALF_WIDTH + 0.2), 0.05, 0.0)
	add_child(m)
	return m


## The cross-section a mould stamps, as real geometry.
##
## `sides` and `bulge` come from the tuning table, so the die on the press and
## the candles that come out of it are built from the same two numbers and
## cannot disagree. A press that stamps an invisible shape is a multiplier with
## a gantry over it.
func _mould_mesh(m: int) -> Mesh:
	var d: Dictionary = Wax.MOULDS[m]
	var sides := int(d.sides)
	var bulge := float(d.bulge)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := PackedVector3Array()
	for i in sides:
		var a := TAU * float(i) / float(sides)
		var r := 0.5 * (1.0 + bulge * cos(a * float(sides)))
		ring.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	# side wall
	for i in sides:
		var p0 := ring[i]
		var p1 := ring[(i + 1) % sides]
		var a0 := p0 + Vector3(0, -0.5, 0)
		var a1 := p1 + Vector3(0, -0.5, 0)
		var b0 := p0 + Vector3(0, 0.5, 0)
		var b1 := p1 + Vector3(0, 0.5, 0)
		st.add_vertex(a0); st.add_vertex(b0); st.add_vertex(b1)
		st.add_vertex(a0); st.add_vertex(b1); st.add_vertex(a1)
	# caps
	for i in sides:
		var p0 := ring[i]
		var p1 := ring[(i + 1) % sides]
		st.add_vertex(Vector3(0, 0.5, 0))
		st.add_vertex(p0 + Vector3(0, 0.5, 0))
		st.add_vertex(p1 + Vector3(0, 0.5, 0))
		st.add_vertex(Vector3(0, -0.5, 0))
		st.add_vertex(p1 + Vector3(0, -0.5, 0))
		st.add_vertex(p0 + Vector3(0, -0.5, 0))
	st.generate_normals()
	return st.commit()


## One station rig, reused for whichever station is nearest.
##
## Everything a station can be is built once and hidden; `_dress_rig` shows the
## parts that belong to the kind in front of the player. Building them per
## station would allocate meshes during play.
func _make_rig() -> Node3D:
	var g := Node3D.new()
	add_child(g)
	var halves: Array[Dictionary] = []
	for i in 2:
		var side := 1 if i == 1 else -1
		var h := Node3D.new()
		h.position.x = float(side) * (Tuning.ROAD_HALF_WIDTH * 0.5)
		g.add_child(h)

		## The reference hangs each sign from a thin dark CURVED ARM rising from
		## the track edge and leaning in over the pool, like a street lamp - not
		## from a gantry with a post either side. It is most of why its runway
		## reads as open sky rather than as a tunnel.
		##
		## Built from a post and a leaning boom rather than an arc: `TorusMesh` has
		## no arc parameter in Godot 4, so a "curved arm" made from one is a
		## complete ring lying flat across the track - which is what it drew.
		var post := MeshInstance3D.new()
		post.mesh = _box(0.14, 4.0, 0.14)
		post.material_override = _mat(Color(0.184, 0.231, 0.322))
		post.position = Vector3(float(side) * (Tuning.ROAD_HALF_WIDTH - 0.2), 2.0, 0.0)
		h.add_child(post)

		var boom := MeshInstance3D.new()
		boom.mesh = _box(2.3, 0.13, 0.13)
		boom.material_override = _mat(Color(0.184, 0.231, 0.322))
		boom.position = Vector3(float(side) * (Tuning.ROAD_HALF_WIDTH - 1.3), 3.9, 0.0)
		boom.rotation = Vector3(0, 0, float(side) * 0.16)
		h.add_child(boom)

		var sign_node := MeshInstance3D.new()
		sign_node.mesh = _box(3.0, 0.86, 0.20)
		sign_node.material_override = _mat(PINK)
		sign_node.position = Vector3(float(side) * 0.3, 3.62, 0.0)
		h.add_child(sign_node)

		## The label, so a station says what it is. `Label3D` is a billboarded
		## quad - no font atlas to build and no canvas to keep in step with the
		## world - and it is the only text in the 3D scene.
		var label := Label3D.new()
		label.text = "CANDLE"
		label.font_size = 96
		label.pixel_size = 0.006
		label.modulate = Color.WHITE
		label.outline_size = 22
		label.outline_modulate = Color(0.55, 0.03, 0.22)
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.rotation = Vector3(0, PI, 0)
		label.position = Vector3(float(side) * 0.3, 3.62, -0.14)
		h.add_child(label)

		## A VAT, not a decal. The reference's wax stands proud of the track with
		## a visible side wall and a thick top - a flat plane painted on the road
		## reads as carpet, and the depth is what says the candles are being
		## dragged THROUGH something.
		var w := Tuning.ROAD_HALF_WIDTH - Tuning.POOL_INSET * 2.0
		var wall := MeshInstance3D.new()
		wall.mesh = _box(w + 0.34, 0.72, Tuning.POOL_LENGTH + 0.34)
		wall.material_override = _mat(Color.WHITE)
		wall.position.y = 0.28
		h.add_child(wall)
		var liquid := MeshInstance3D.new()
		liquid.mesh = _box(w, 0.52, Tuning.POOL_LENGTH)
		liquid.material_override = _mat(Color.WHITE)
		liquid.position.y = 0.24
		h.add_child(liquid)

		# the machine over it
		var head := Node3D.new()
		head.position = Vector3(float(side) * 0.1, 2.6, -Tuning.POOL_LENGTH * 0.5 + 1.4)
		h.add_child(head)

		## A LADLE, not a ball on a stick: an open bowl with a rim, wax visible
		## inside it, tipped so the stream leaves the LIP. A whole sphere with a
		## cylinder under its middle reads as a lollipop being waved, and a
		## stream leaving the centre of a sphere is leaking rather than pouring.
		var bowl := MeshInstance3D.new()
		bowl.mesh = _cyl(0.70, 0.34, 0.62, 14)
		bowl.material_override = _mat(CHROME)
		head.add_child(bowl)
		var inner := MeshInstance3D.new()
		inner.mesh = _cyl(0.60, 0.30, 0.14, 14)
		inner.material_override = _mat(Color.WHITE)
		inner.position.y = 0.14
		head.add_child(inner)
		var pour := MeshInstance3D.new()
		pour.mesh = _cyl(0.17, 0.26, 2.6, 10)
		pour.material_override = _mat(Color.WHITE)
		pour.position = Vector3(0.52, -1.35, 0.0)
		pour.rotation_degrees = Vector3(0, 0, 9)
		head.add_child(pour)

		var gift := MeshInstance3D.new()
		gift.mesh = _box(1.6, 1.5, 1.6)
		gift.material_override = _mat(GOLD)
		head.add_child(gift)

		## The die, one per mould shape, and only the pressed one visible - so
		## the machine standing over the track IS the shape you get.
		var dies: Array[MeshInstance3D] = []
		for m in Wax.MOULDS.size():
			var d := MeshInstance3D.new()
			d.mesh = _mould_mesh(m)
			d.scale = Vector3(2.4, 2.0, 2.4)
			d.material_override = _mat(PINK)
			d.visible = false
			head.add_child(d)
			dies.append(d)

		var plate := MeshInstance3D.new()
		plate.mesh = _box(Tuning.ROAD_HALF_WIDTH - 0.2, 0.22, 2.8)
		plate.material_override = _mat(Color.WHITE)
		plate.position.y = 0.14
		h.add_child(plate)

		halves.append({
			"node": h, "sign": sign_node, "label": label, "wall": wall, "liquid": liquid,
			"head": head, "bowl": bowl, "inner": inner, "pour": pour,
			"gift": gift, "dies": dies, "plate": plate, "side": side,
		})
	g.visible = false
	g.set_meta("halves", halves)
	return g


# --- HUD ------------------------------------------------------------------

## THE LAYOUT RULE, and it is here because getting it wrong has shipped.
##
## `window/stretch/aspect = "expand"` keeps the base WIDTH and extends the
## HEIGHT to the device's aspect, so the canvas is about 1080x2340 on the phone
## and not 1080x1920. Laying anything out against the literal base height puts
## it hundreds of pixels above where it belongs.
##
## So: one `Control` with `PRESET_FULL_RECT`, and everything anchors to that.
## Every interactive control handles its own input through `_gui_input`, so its
## hit box and its drawing are the same object and cannot drift apart.
##
## No headless test can catch this - a headless run uses the base viewport size,
## where the wrong layout and the right one are identical. Screenshot at the
## phone's aspect, and assert the PROPERTY (that it resolves from the viewport
## edge) rather than the position.
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)

	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.name = "Ui"
	layer.add_child(_ui)

	## THE HUD IS THREE THINGS: a settings gear, the level, and the money. The
	## reference has no candle counter, no running value, no colour chips and no
	## progress bar; value arrives as floating green text over the batch and
	## nothing else. Adding readouts is the easiest way to stop looking like it.
	_gear = Control.new()
	_gear.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_gear.position = Vector2(40, 60)
	_gear.custom_minimum_size = Vector2(112, 112)
	_gear.size = Vector2(112, 112)
	_gear.mouse_filter = Control.MOUSE_FILTER_STOP
	_gear.name = "Gear"
	_gear.gui_input.connect(_on_gear_input)
	_gear.draw.connect(_draw_gear)
	_ui.add_child(_gear)

	_level_pill = _pill(Control.PRESET_CENTER_TOP, Vector2(0, 60), 44)
	_money_pill = _pill(Control.PRESET_TOP_RIGHT, Vector2(-40, 60), 44)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 520
	_toast.offset_left = -420
	_toast.offset_right = 420
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 84)
	_toast.add_theme_color_override("font_color", Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", Color(0.16, 0.05, 0.22))
	_toast.add_theme_constant_override("outline_size", 18)
	_toast.modulate.a = 0.0
	_ui.add_child(_toast)


func _pill(preset: int, offset: Vector2, font: int) -> Label:
	var l := Label.new()
	l.set_anchors_preset(preset)
	l.position = offset
	if preset == Control.PRESET_TOP_RIGHT:
		l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif preset == Control.PRESET_CENTER_TOP:
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.05, 0.22))
	l.add_theme_constant_override("outline_size", 14)
	_ui.add_child(l)
	return l


func _draw_gear() -> void:
	var c := Vector2(56, 56)
	_gear.draw_circle(c, 52, Color(1, 1, 1, 0.92))
	_gear.draw_arc(c, 52, 0.0, TAU, 40, Color(0.16, 0.05, 0.22), 6.0)
	_gear.draw_circle(c, 20, Color(0.48, 0.42, 0.55))
	for i in 6:
		var a := TAU * float(i) / 6.0
		_gear.draw_line(c + Vector2(cos(a), sin(a)) * 24.0,
			c + Vector2(cos(a), sin(a)) * 40.0, Color(0.48, 0.42, 0.55), 9.0)


func _on_gear_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		# Somewhere for settings to live. Until there is a panel, it restarts the
		# level - which is at least an escape from a run that has gone wrong, and
		# is the behaviour the smoke test pins.
		sim.restart(sim.level)
		_stand = 0.0
		_gear.accept_event()


# --- loop -----------------------------------------------------------------

func _process(delta: float) -> void:
	if frozen:
		return
	_tick(delta)


func _tick(dt: float) -> void:
	sim.advance(dt)
	_stand = clampf(_stand + (dt * 2.2 if sim.standing else -dt * 3.0), 0.0, 1.0)
	if _toast_t > 0.0:
		_toast_t -= dt
		_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
	_advance_interlude(dt)
	_sync()


## The only place the world can be started again.
##
## A game built from an earlier version of this template connected nothing to
## `level_finished`: `over` went true at the end of the first level, `advance()`
## returned early from then on, and it sat frozen with a live HUD - which to the
## person holding the phone is a crash. Every test in that suite played a level
## and read the state at the end, which is the exact instant the freeze began.
func _on_level_finished(_value: float) -> void:
	_interlude = INTERLUDE_SECONDS


func _advance_interlude(dt: float) -> void:
	if _interlude <= 0.0:
		return
	_interlude -= dt
	if _interlude > 0.0:
		return
	sim.restart(sim.level + 1)
	_stand = 0.0


func _on_stood_up(_z: float) -> void:
	_say("STAND UP")


func _on_hit(_kind: String, _x: float, _z: float, n: int) -> void:
	if n > 0:
		_say("-%d" % n)


func _say(msg: String) -> void:
	_toast.text = msg
	_toast_t = 1.4


## The headless seam. Freeze first: real frames run between the scene loading
## and a harness taking over, and how many depends on how fast the machine
## starts - which quietly makes every recorded number a function of the test
## runner's speed.
func advance(seconds: float, step: float = 1.0 / 60.0) -> void:
	_ensure_booted()
	var n := maxi(1, int(round(seconds / step)))
	for i in n:
		_tick(step)


func freeze(start_level: int = 1) -> void:
	_ensure_booted()
	frozen = true
	sim.restart(start_level)
	_interlude = 0.0
	_stand = 0.0
	_sync()


# --- drawing --------------------------------------------------------------

func _sync() -> void:
	var z := sim.distance
	_draw_camera(z)

	_road.position.z = z
	_rail_l.position.z = z
	_rail_r.position.z = z

	_draw_stripes(z)
	_draw_skyline(z)
	_draw_batch()
	_draw_pickups()
	_draw_obstacles()
	_draw_stations()

	_level_pill.text = "Level %d" % sim.level
	_money_pill.text = "%s $" % SimUtil.fmt(sim.cash)


## The camera is LOW and close behind. The bands run around a candle, so they
## are only legible from the side: a high camera sees the tops and a
## three-colour batch reads as one colour. It lifts a little once the batch is
## standing, because a standing rank is taller than a lying loaf.
func _draw_camera(z: float) -> void:
	var tail := clampf(Trail.back_for(sim.count() - 1), 0.0, 16.0)
	var up := _stand * 2.2
	var eye := Vector3(sim.x * 0.55, 5.4 + tail * 0.18 + up,
		z - 11.5 - tail * 0.45 - up * 1.2)
	var focus := Vector3(sim.x * 0.35, 1.2, z + 16.0)
	# Transform3D.looking_at, not Node3D.look_at: the node method requires the
	# node to be in the tree and errors when it is not, which is exactly the
	# headless case. This is pure maths and works anywhere.
	_cam.transform = Transform3D(Basis.IDENTITY, eye).looking_at(focus, Vector3.UP)
	_cam_z = eye.z


func _draw_stripes(z: float) -> void:
	var mm := _stripes.multimesh
	var first := int((z - 20.0) / 3.2)
	var n := 0
	for i in 60:
		if n >= 64:
			break
		mm.set_instance_transform(n, Transform3D(Basis.IDENTITY,
			Vector3(0, 0.02, float(first + i) * 3.2)))
		n += 1
	mm.visible_instance_count = n


## Pale stacked-cylinder towers, like giant candle stacks, well below the track.
## Windowed on the player's position rather than held for a whole level.
func _draw_skyline(z: float) -> void:
	var mmt := _towers.multimesh
	var mmc := _tower_tips.multimesh
	var nt := 0
	var nc := 0
	var c0 := int(z / 60.0) - 1
	for c in range(c0, c0 + 6):
		for k in 3:
			if nc >= POOL or nt + 4 >= POOL * 2:
				break
			var side := 1.0 if SimUtil.hash2(c, 3100 + k) > 0.5 else -1.0
			var tx := side * (15.0 + SimUtil.hash2(c, 3110 + k) * 24.0)
			var ty := -13.0 - SimUtil.hash2(c, 3115 + k) * 7.0
			var tz := float(c) * 60.0 + SimUtil.hash2(c, 3120 + k) * 60.0
			var s := 1.5 + SimUtil.hash2(c, 3130 + k) * 1.5
			var drums := 2 + int(SimUtil.hash2(c, 3140 + k) * 3.4)
			var y := ty
			for d in drums:
				# Each drum a little narrower than the one under it, which is
				# what makes a plain cylinder stack read as a candle rather than
				# as a chimney.
				var r := s * (1.0 - float(d) * 0.13)
				var h := s * (1.5 + float(d % 2) * 0.5)
				mmt.set_instance_transform(nt, Transform3D(
					Basis.IDENTITY.scaled(Vector3(r, h, r)), Vector3(tx, y + h * 0.5, tz)))
				nt += 1
				y += h
			mmc.set_instance_transform(nc, Transform3D(
				Basis.IDENTITY.scaled(Vector3(s, s, s)), Vector3(tx, y + s * 0.5, tz)))
			nc += 1
	mmt.visible_instance_count = nt
	mmc.visible_instance_count = nc


## THE BATCH, in its two forms.
##
## Lying down, a candle is a cylinder across the lane with its bands stacked
## along its length and a gold tip out of one end. Standing, the same bands run
## UP it - which is what a dipped candle actually looks like, and the reason
## standing up is the moment the player can finally read every colour they put
## on. `_stand` blends between the two.
##
## reset -> push -> flush, in the one place it can be got wrong.
## `visible_instance_count` is the flush; forgetting it leaves the count at
## whatever it was last frame while the simulation carries on perfectly.
func _draw_batch() -> void:
	var counts := PackedInt32Array()
	counts.resize(_bands.size())
	counts.fill(0)
	var nw := 0
	var nr := 0
	var nb := 0
	var ns := 0

	var pos := sim.positions()
	var t := _stand
	for i in mini(pos.size(), sim.count()):
		var c := sim.batch[i]
		var p := pos[i]
		var radii := c.radii()
		var offs := c.band_offsets()
		var bh := c.band_height()
		var len := c.length()
		var mm := _bands[c.mould].multimesh
		var n := counts[c.mould]

		for b in c.layers.size():
			var r := radii[b]
			var col := Wax.colour(c.layers[b])
			if c.glitter > 0:
				col = col.lerp(Color.WHITE, 0.10 * float(c.glitter))
			if c.scent > 0:
				col = col.lerp(Color(0.847, 0.706, 1.0), 0.16)
			var basis: Basis
			var at: Vector3
			if t > 0.5:
				# upright: bands stack in height
				basis = Basis.IDENTITY.scaled(Vector3(r * 2.0, bh, r * 2.0))
				at = Vector3(p.x, offs[b], p.y)
			else:
				# lying: the cylinder runs across the lane
				## `Basis.scaled()` scales the WORLD axes, not the mesh's own, so
				## the scale vector has to be written in the orientation the band
				## ENDS UP in rather than the one the cylinder starts in. Rotated
				## about Z, its axis is world X. Getting that backwards drew the
				## batch as a heap of overlapping boxes instead of a striped bar,
				## which looks like a layout bug and is a transform one.
				basis = Basis(Vector3(0, 0, 1), PI * 0.5).scaled(Vector3(bh, r * 2.0, r * 2.0))
				at = Vector3(p.x + offs[b] - len * 0.5, radii[0], p.y)
			if n < BANDS:
				mm.set_instance_transform(n, Transform3D(basis, at))
				mm.set_instance_color(n, col)
				n += 1
		counts[c.mould] = n

		# the gold tip
		if nw < Tuning.MAX_CANDLES:
			var wb: Basis
			var wat: Vector3
			if t > 0.5:
				wb = Basis.IDENTITY.scaled(Vector3(radii[0] * 1.6, Tuning.WICK_HEIGHT * 1.6, radii[0] * 1.6))
				wat = Vector3(p.x, len + Tuning.WICK_HEIGHT * 0.5, p.y)
			else:
				wb = Basis(Vector3(0, 0, 1), -PI * 0.5).scaled(
					Vector3(Tuning.WICK_HEIGHT * 1.4, radii[0] * 1.4, radii[0] * 1.4))
				wat = Vector3(p.x + len * 0.5 + Tuning.WICK_HEIGHT * 0.4, radii[0], p.y)
			_wicks.multimesh.set_instance_transform(nw, Transform3D(wb, wat))
			nw += 1

		# wrapping: a ribbon round it and a bow on it, per candle
		if c.wrap > 0 and nr < Tuning.MAX_CANDLES:
			var w: Dictionary = Wax.WRAPS[c.wrap]
			var rr := radii[radii.size() - 1]
			var ry := len * 0.42 if t > 0.5 else rr
			_ribbons.multimesh.set_instance_transform(nr, Transform3D(
				Basis.IDENTITY.scaled(Vector3(rr * 2.3, len * 0.16, rr * 2.3)),
				Vector3(p.x, ry, p.y)))
			_ribbons.multimesh.set_instance_color(nr, w.col)
			nr += 1
			if nb < Tuning.MAX_CANDLES:
				_bows.multimesh.set_instance_transform(nb, Transform3D(
					Basis.IDENTITY.scaled(Vector3(rr * 1.9, len * 0.10, rr * 0.7)),
					Vector3(p.x, ry + len * 0.11, p.y)))
				_bows.multimesh.set_instance_color(nb, w.bow)
				nb += 1

		if c.glitter > 0 and i % 2 == 0 and ns < Tuning.MAX_CANDLES:
			_sparks.multimesh.set_instance_transform(ns, Transform3D(Basis.IDENTITY,
				Vector3(p.x + radii[0] * 1.2, (len * 0.6 if t > 0.5 else radii[0] * 2.0), p.y)))
			ns += 1

	for m in _bands.size():
		_bands[m].multimesh.visible_instance_count = counts[m]
	_wicks.multimesh.visible_instance_count = nw
	_ribbons.multimesh.visible_instance_count = nr
	_bows.multimesh.visible_instance_count = nb
	_sparks.multimesh.visible_instance_count = ns


func _draw_pickups() -> void:
	var mm := _loose.multimesh
	var mt := _loose_tips.multimesh
	var n := 0
	for c in sim.loose:
		if bool(c.taken) or n >= POOL:
			continue
		# Lying at their own angle. A dozen identical capsules all pointing the
		# same way reads as a printed pattern rather than as stock where it fell.
		var lie := float(c.lie)
		var b := Basis(Vector3(0, 1, 0), lie) * Basis(Vector3(1, 0, 0), PI * 0.5)
		var at := Vector3(float(c.x), 0.34, float(c.z))
		mm.set_instance_transform(n, Transform3D(b.scaled(Vector3(1, 1.15, 1)), at))
		mt.set_instance_transform(n, Transform3D(b,
			at + Vector3(sin(lie) * 0.72, 0.0, cos(lie) * 0.72)))
		n += 1
	mm.visible_instance_count = n
	mt.visible_instance_count = n

	var mn := _notes.multimesh
	var mh := _note_holes.multimesh
	var k := 0
	for b2 in sim.notes:
		if bool(b2.taken) or k >= POOL:
			continue
		var at2 := Vector3(float(b2.x), 0.14, float(b2.z))
		mn.set_instance_transform(k, Transform3D(Basis.IDENTITY, at2))
		mh.set_instance_transform(k, Transform3D(Basis.IDENTITY, at2 + Vector3(-0.42, 0.04, 0)))
		k += 1
	mn.visible_instance_count = k
	mh.visible_instance_count = k


func _draw_obstacles() -> void:
	var mb := _barriers.multimesh
	var ms := _spikes.multimesh
	var mk := _bar_marks.multimesh
	var mw := _sweepers.multimesh
	var mt := _sweep_tips.multimesh
	var mp := _posts.multimesh
	var nb := 0
	var ns := 0
	var nk := 0
	var nw := 0
	var nt := 0
	var np := 0

	for o in sim.obstacles:
		if bool(o.hit):
			continue
		var ox := float(o.x)
		var oz := float(o.z)
		match String(o.kind):
			"barrier":
				# A ROW OF PYRAMIDS on a low base, not a flat panel: seen at
				# speed the reference's is a zigzag red wall with white crosses.
				if nb < POOL:
					mb.set_instance_transform(nb, Transform3D(Basis.IDENTITY, Vector3(ox, 0.26, oz)))
					nb += 1
				for i in range(-1, 2):
					if ns >= POOL * 2:
						break
					var px := ox + float(i) * 0.62
					ms.set_instance_transform(ns, Transform3D(Basis.IDENTITY, Vector3(px, 0.86, oz)))
					ns += 1
					for m in 2:
						if nk >= POOL * 3:
							break
						var ang := 0.86 if m == 1 else -0.86
						mk.set_instance_transform(nk, Transform3D(
							Basis(Vector3(0, 0, 1), ang), Vector3(px, 0.80, oz - 0.30)))
						nk += 1
			"roller":
				# A pale post OUTSIDE the rail with a shaft reaching part way
				# across, carrying interlocking coral diamonds. Anchoring it is
				# what guarantees the gap is on the far side.
				var side := float(o.side)
				var reach := float(o.reach)
				if np < POOL:
					mp.set_instance_transform(np, Transform3D(Basis.IDENTITY,
						Vector3(side * (Tuning.ROAD_HALF_WIDTH + 0.55), 1.7, oz)))
					np += 1
				var cnt := maxi(2, int(round(reach / 0.92)))
				for k in cnt:
					if ns >= POOL * 2:
						break
					var f := (float(k) + 0.5) / float(cnt)
					ms.set_instance_transform(ns, Transform3D(
						Basis(Vector3(1, 0, 0), float(k) * 0.4).scaled(Vector3(1.5, 1.5, 1.5)),
						Vector3(side * Tuning.ROAD_HALF_WIDTH - side * reach * f, 1.0, oz)))
					ns += 1
			"sweeper":
				# A thin salmon bar lying diagonally, with a navy arrowhead at
				# the leading end showing which way it is sliding.
				var a := 0.42 * float(o.dir)
				if nw < POOL:
					mw.set_instance_transform(nw, Transform3D(
						Basis(Vector3(0, 1, 0), a), Vector3(ox, 0.32, oz)))
					nw += 1
				var vx := cos(float(o.phase) + sim.distance * 0.26 * float(o.dir)) * float(o.dir)
				var way := 1.0 if vx >= 0.0 else -1.0
				if nt < POOL:
					mt.set_instance_transform(nt, Transform3D(
						Basis(Vector3(0, 1, 0), a) * Basis(Vector3(0, 0, 1), -way * PI * 0.5),
						Vector3(ox + way * 1.95 * cos(a), 0.32, oz - way * 1.95 * sin(a))))
					nt += 1

	mb.visible_instance_count = nb
	ms.visible_instance_count = ns
	mk.visible_instance_count = nk
	mw.visible_instance_count = nw
	mt.visible_instance_count = nt
	mp.visible_instance_count = np


func _draw_stations() -> void:
	var i := 0
	for st in sim.stations:
		if i >= _rigs.size():
			break
		var sz := float(st.z)
		## Behind the CAMERA, not behind the batch: the camera sits about
		## fifteen metres back, so a station culled at the batch's own
		## position is still in shot - and its sign fills the bottom of
		## the screen from a metre away.
		if sz < _cam_z + 5.0 or sz > sim.distance + 130.0:
			continue
		_dress_rig(_rigs[i], st, sz)
		i += 1
	for k in range(i, _rigs.size()):
		_rigs[k].visible = false


func _dress_rig(rig: Node3D, st: Dictionary, sz: float) -> void:
	rig.visible = true
	rig.position = Vector3(0, 0, sz)
	var halves: Array = rig.get_meta("halves")
	for hi in 2:
		var h: Dictionary = halves[hi]
		var half: Dictionary = st.left if hi == 0 else st.right
		var kind := int(half.kind)
		var k: Dictionary = Stations.KINDS[kind]
		var col := _kind_colour(half)
		var liquid := bool(k.liquid)
		var beat := sim.time * 2.2 + float(hi) * 0.7 + sz * 0.11

		h.sign.material_override = _mat(PINK)
		var label: Label3D = h.label
		label.text = String(k.label)
		var wall: MeshInstance3D = h.wall
		var liq: MeshInstance3D = h.liquid
		wall.visible = liquid
		wall.material_override = _mat(col.darkened(0.38))
		liq.visible = kind != Stations.ROTATE
		liq.material_override = _mat(col)
		liq.scale.y = 1.0 if liquid else 0.07
		liq.position.y = 0.24 if liquid else 0.03

		var machine := String(k.machine)
		var head: Node3D = h.head
		var bowl: MeshInstance3D = h.bowl
		var inner: MeshInstance3D = h.inner
		var pour: MeshInstance3D = h.pour
		var gift: MeshInstance3D = h.gift
		var plate: MeshInstance3D = h.plate
		var dies: Array = h.dies

		bowl.visible = machine == "ladle" or machine == "bottle"
		inner.visible = bowl.visible
		pour.visible = bowl.visible
		gift.visible = machine == "gift"
		plate.visible = machine == "arrow"
		for d in dies:
			d.visible = false

		if bowl.visible:
			inner.material_override = _mat(col)
			pour.material_override = _mat(col)
			# HELD, and tipped just enough to spill over the rim. A ladle that is
			# pouring barely moves; what moves is the wax.
			head.position.y = 2.55 + sin(beat) * 0.08
			head.rotation = Vector3(0, 0, 0.62 + sin(beat * 1.3) * 0.07)
		elif machine == "ram":
			dies[int(half.mould)].visible = true
			var drop := pow(maxf(0.0, sin(beat * 1.7)), 0.55)
			head.position.y = 3.0 - drop * 2.3
			head.rotation = Vector3(0, beat * 0.25, 0)
		elif machine == "gift":
			head.position.y = 1.5 + sin(beat) * 0.18
			head.rotation = Vector3(0, beat * 0.4, 0)
		else:
			head.position.y = 0.12
			head.rotation = Vector3.ZERO


func _kind_colour(half: Dictionary) -> Color:
	match int(half.kind):
		Stations.WAX:
			return Wax.colour(int(half.wax))
		Stations.GLITTER:
			return GOLD
		Stations.PRESS:
			return Color(0.545, 0.878, 1.0)
		Stations.WRAP:
			var w: Dictionary = Wax.WRAPS[int(half.wrap)]
			return w.col
		Stations.SCENT:
			return Color(0.847, 0.706, 1.0)
	return Color.WHITE


# --- input ----------------------------------------------------------------

## Drag anywhere, relative rather than absolute.
##
## The thumb is never where the player is looking, and an absolute mapping makes
## the first touch of every run yank the batch sideways. The reference's only
## tutorial is a double-headed arrow, which is what this is.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_dragging = event.pressed
	elif event is InputEventMouseButton:
		_dragging = event.pressed
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and _dragging):
		var dx: float = event.relative.x
		var span := float(get_viewport().get_visible_rect().size.x)
		sim.steer_to(sim.target_x + dx / span * Tuning.LANE_HALF_WIDTH * 3.4)


# --- helpers --------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


func _cyl(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = sides
	return m


## One MultiMesh per kind, rewritten every frame.
##
## `visible_instance_count` is the whole reason to use this rather than a pool of
## nodes: it is a number the tests can compare against the model. A render path
## that silently stops drawing and a subsystem that does not exist look identical
## from outside, and that has already cost a full tuning pass on another game.
func _mm(mesh: Mesh, c: Color, count: int, tinted: bool = false) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	## BEFORE `instance_count`, always. Godot refuses to toggle per-instance
	## colours once a buffer exists - "Instance count must be 0 to toggle
	## whether colors are used" - and the error is a runtime one that leaves the
	## mesh silently untinted rather than failing the build.
	mm.use_colors = tinted
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	mmi.multimesh = mm
	var m := _mat(c)
	m.vertex_color_use_as_albedo = true
	mmi.material_override = m
	add_child(mmi)
	return mmi
