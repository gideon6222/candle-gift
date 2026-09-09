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
var _home: Control
var _ruler: Control
var _reward: Control
var _reward_amount: Label
var _reward_best: Label
var _reward_take: Button
var _shop: Control
var _shop_rows: VBoxContainer
var _shop_scroll: ScrollContainer
var _boost_candle: Button
var _boost_cash: Button
## Fredoka, the reference's face: a rounded geometric sans. Loaded once and
## shared - a Label that falls back to the engine default is the single most
## obvious way a screen stops looking like the game it is copying.
var _font: FontFile
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
## A RUN IS FOUR PHASES, and every screen in the game is one of them.
##
## The reference has no menu that stops the world: between runs the player sits
## ON the runway with the level already built behind the cards, and the first
## swipe starts it. So HOME is not "before the game", it is the game with the
## simulation not yet advancing - `_sync()` still runs, so what you are looking
## at is the level you are about to play.
enum Phase { HOME, RUN, RULER, REWARD, SHOP }

var _phase: int = Phase.HOME
var _run_value := 0.0
var _run_best := 0.0
var _beat_best := false
var _ruler_t := 0.0
var _interlude := 0.0
var _state := {}

## Set by the headless harness. When true the frame loop does not step the sim,
## so `advance()` is the only thing moving time and results do not depend on how
## fast the machine boots.
var frozen := false

## How long the batch takes to climb the money ruler.
const RULER_SECONDS := 2.6
const INTERLUDE_SECONDS := 2.4

# --- the palette, in one place -------------------------------------------
## The ink for every outline. Not black: a pure black line on flat pastels
## reads as a comic panel rather than as a toy, and the reference's lines
## are a very dark desaturated navy.
const INK := Color(0.114, 0.106, 0.208)
const SKY := Color(0.071, 0.702, 0.933)
## The top of the gradient. Darker than SKY, never lighter - see _build_world.
const SKY_TOP := Color(0.035, 0.463, 0.827)
## The gold of the HUD pills, and the dark line around them.
const PILL := Color(1.000, 0.769, 0.078)
const NOTE := Color(0.180, 0.686, 0.353)
## The reward card is a full-screen magenta modal in the reference.
const MODAL := Color(0.784, 0.098, 0.427)
const BOOST_PRICE := 500.0
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
## The ladle: frosted pale ice-blue, not metal.
const LADLE := Color(0.815, 0.902, 0.957)
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
	_state = Save.load_state()
	sim = Sim.new()
	_build_world()
	sim.level_finished.connect(_on_level_finished)
	sim.stood_up.connect(_on_stood_up)
	sim.hit_obstacle.connect(_on_hit)
	_apply_save()
	_sync()


# --- world ----------------------------------------------------------------

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	## A GRADIENT SKY, deeper at the top, and it is also the ambient and the
	## reflection source.
	##
	## This replaces the CC0 HDRI that was here. That was kept for one reason -
	## a glossy surface with nothing to reflect renders as a dull plate - under
	## the rule "take the lighting, leave the picture", with the background left
	## as flat colour because a photographic sky behind a flat-shaded game looks
	## like two games at once.
	##
	## Read at 1080p, the reference's sky is a gradient, and a gradient of OUR
	## OWN colours has no join to show: it can be the background and the ambient
	## at the same time, which an environment only supports for one sky. What is
	## given up is a detailed reflection, and at the 0.45 gloss the wax settled
	## on that was worth less than the sky being right.
	##
	## The horizon end never goes lighter than the flat colour it replaces. A
	## sky that fades toward white puts a white runway against a near-white
	## backdrop at exactly the distance the player steers by, and the track
	## dissolves about twenty metres out - the same failure as a pink road under
	## a pink sky. The gradient is allowed to go DARKER upward and nowhere else.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SKY_TOP
	sky_mat.sky_horizon_color = SKY
	sky_mat.ground_horizon_color = SKY
	sky_mat.ground_bottom_color = SKY
	sky_mat.sky_curve = 0.18
	sky_mat.sun_angle_max = 1.0
	sky_mat.energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.sky = sky
	e.background_mode = Environment.BG_SKY
	## BACKGROUND from the sky, AMBIENT from a neutral colour, REFLECTIONS from
	## the sky. An Environment lets these be three different sources and they
	## have to be, because a blue sky is blue AMBIENT.
	##
	## Taking ambient from the sky as well turned every station sign from
	## magenta to navy: the sign faces the camera, the sun is behind and above,
	## so the face is lit by ambient alone - and blue ambient times a magenta
	## albedo has almost no red left in it. Anything warm that is not in direct
	## sun goes dark and slightly wrong, which is the hardest kind of wrong to
	## trace back to the light.
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.88, 0.91, 0.97)
	e.ambient_light_energy = 0.78
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -34, 0)
	sun.light_energy = 1.0
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
	## No line on the stripes: they are seen almost edge-on the whole time,
	## which is exactly where a fresnel rim darkens a whole face.
	_stripes = _mm(_box(Tuning.ROAD_HALF_WIDTH * 2.0, 0.06, 1.1), STRIPE, 64, false, 0.0)

	# the batch
	for m in Wax.MOULDS.size():
		var mm := _mm(_mould_mesh(m), Color.WHITE, BANDS, true)
		_bands.append(mm)
	_wicks = _mm(_cyl(0.16, 0.16, 1.0, 7), GOLD, Tuning.MAX_CANDLES)
	_ribbons = _mm(_box(1.0, 1.0, 1.0), PINK, Tuning.MAX_CANDLES, true)
	_bows = _mm(_box(1.0, 1.0, 1.0), GOLD, Tuning.MAX_CANDLES, true)
	_sparks = _mm(_box(0.10, 0.10, 0.10), Color.WHITE, Tuning.MAX_CANDLES)

	# pickups
	_loose = _mm(_loose_mesh(false), Color(1.0, 0.776, 0.102), POOL)
	_loose_tips = _mm(_loose_mesh(true), Color(0.98, 0.98, 0.96), POOL, false, 0.12)
	_notes = _mm(_box(1.15, 0.09, 0.60), GREEN, POOL)
	_note_holes = _mm(_cyl(0.10, 0.10, 0.16, 8), Color.WHITE, POOL)

	# obstacles
	_barriers = _mm(_shard_cluster(false), CORAL, POOL, false, 0.20)
	_spikes = _mm(_cyl(0.0, 0.50, 0.80, 4), CORAL_LIGHT, POOL * 2)
	_bar_marks = _mm(_shard_cluster(true), CORAL_LIGHT, POOL, false, 0.16)
	_sweepers = _mm(_box(3.4, 0.30, 0.34), SALMON, POOL)
	_sweep_tips = _mm(_cyl(0.0, 0.44, 0.90, 4), NAVY, POOL)
	_posts = _mm(_box(0.40, 3.4, 0.40), Color(0.561, 0.510, 0.600), POOL)

	# scenery: pale stacked-cylinder candle towers, well below the track
	_towers = _mm(_cyl(1.0, 1.0, 1.0, 10), TOWER, POOL * 2, false, 0.22)
	_tower_tips = _mm(_cyl(0.0, 0.62, 1.3, 8), GOLD, POOL, false, 0.22)

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
## A CONE, wound to match the cap in `_mould_mesh`.
##
## Winding is copied from geometry that is known to render right rather than
## derived. Godot treats clockwise as front-facing, `generate_normals()` takes
## its normals from the winding, and getting it backwards produces a mesh that
## is lit from inside and culled from outside - which looks like a lighting bug
## and is a vertex-order one.
func _add_cone(st: SurfaceTool, at: Vector3, r: float, h: float,
		lean: float, sides: int) -> void:
	var apex := at + Vector3(lean * h, h, 0.0)
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var p0 := at + Vector3(cos(a0) * r, 0.0, sin(a0) * r)
		var p1 := at + Vector3(cos(a1) * r, 0.0, sin(a1) * r)
		st.add_vertex(apex); st.add_vertex(p0); st.add_vertex(p1)
		# and a floor, so a shard seen from below is not hollow
		st.add_vertex(at); st.add_vertex(p1); st.add_vertex(p0)


func _add_tube(st: SurfaceTool, at: Vector3, r: float, h: float, sides: int) -> void:
	var half := h * 0.5
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var d0 := Vector3(cos(a0) * r, 0.0, sin(a0) * r)
		var d1 := Vector3(cos(a1) * r, 0.0, sin(a1) * r)
		var b0 := at + d0 - Vector3(0, half, 0)
		var b1 := at + d1 - Vector3(0, half, 0)
		var t0 := at + d0 + Vector3(0, half, 0)
		var t1 := at + d1 + Vector3(0, half, 0)
		st.add_vertex(b0); st.add_vertex(t0); st.add_vertex(t1)
		st.add_vertex(b0); st.add_vertex(t1); st.add_vertex(b1)
		st.add_vertex(at + Vector3(0, half, 0)); st.add_vertex(t0); st.add_vertex(t1)
		st.add_vertex(at - Vector3(0, half, 0)); st.add_vertex(b1); st.add_vertex(b0)


## A CLUSTER OF JAGGED SHARDS, which is what the reference's hazard is: a growth
## rising off the track with a CURVED silhouette, brighter coral at the tips
## over a deeper red-orange base.
##
## It was a row of three equal pyramids on a low base with white crosses on it,
## read off a 360p frame. Three identical pyramids in a line is a fence; what
## makes this read as a growth is that no two shards are the same height and the
## outer ones lean away from the middle.
##
## The whole cluster is ONE MESH and therefore one instance per obstacle, which
## keeps `visible_instance_count` comparable against the number of barriers in
## the model - the assertion that catches a lost flush. Built out of ten
## instances it would have been a number that means nothing.
func _shard_cluster(tips: bool) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 7
	for i in n:
		var f := (float(i) + 0.5) / float(n)
		var x := (f - 0.5) * 1.85
		# tall in the middle, short at the ends
		var bell := 1.0 - pow(absf(f - 0.5) * 2.0, 1.6)
		# and never exactly the bell, or the silhouette is a smooth arc
		var jag := 0.82 + 0.36 * SimUtil.hash2(i, 7701)
		var h := (0.50 + bell * 0.95) * jag
		var r := 0.13 + bell * 0.085
		var lean := (f - 0.5) * 0.55
		var base := 0.0
		if tips:
			## The bright cap sits on the shoulder of its own shard, so the two
			## meshes cannot drift apart: both are functions of the same numbers.
			base = h * 0.55
			r *= 0.55
			h *= 0.45
		_add_cone(st, Vector3(x, base, 0.0), r, h, lean, 5)
	st.generate_normals()
	return st.commit()


## THREE candles packed close, at slight angles, each with a thin white wick -
## which is what a loose pickup looks like in the reference, and one fat gold
## cylinder is not. One mesh again, so it stays one instance per pickup and the
## smoke test can still compare the count against the model.
func _loose_mesh(wicks: bool) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var x := (float(i) - 1.0) * 0.30
		var z := (SimUtil.hash2(i, 7801) - 0.5) * 0.26
		if wicks:
			_add_tube(st, Vector3(x, 0.34, z), 0.035, 0.26, 6)
		else:
			_add_tube(st, Vector3(x, 0.0, z), 0.15, 0.62, 9)
	st.generate_normals()
	return st.commit()


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

		## THE OVERHEAD FURNITURE IS A SEPARATE NODE from the pool, because the
		## two have to disappear at different moments. The pool is ground: it
		## stays until its far edge is behind the LENS, or it pops out from
		## under a batch still standing in it. The gantry is overhead: it has
		## to go the moment it is passed, or a three-metre sign sits a few
		## metres from the camera and fills half the frame - which is exactly
		## what one cull distance for both produced.
		var furn := Node3D.new()
		h.add_child(furn)

		## The reference hangs each sign from a thin dark CURVED ARM rising from
		## the track edge and leaning in over the pool, like a street lamp - not
		## from a gantry with a post either side. It is most of why its runway
		## reads as open sky rather than as a tunnel.
		##
		## Built from a post and a leaning boom rather than an arc: `TorusMesh` has
		## no arc parameter in Godot 4, so a "curved arm" made from one is a
		## complete ring lying flat across the track - which is what it drew.
		var post := MeshInstance3D.new()
		post.mesh = _box(0.14, 7.6, 0.14)
		post.material_override = _mat(Color(0.184, 0.231, 0.322))
		post.position = Vector3(float(side) * (Tuning.ROAD_HALF_WIDTH - 0.2), 3.8, 0.0)
		furn.add_child(post)

		var boom := MeshInstance3D.new()
		boom.mesh = _box(2.3, 0.13, 0.13)
		boom.material_override = _mat(Color(0.184, 0.231, 0.322))
		boom.position = Vector3(float(side) * (Tuning.ROAD_HALF_WIDTH - 1.3), 7.3, 0.0)
		boom.rotation = Vector3(0, 0, float(side) * 0.16)
		furn.add_child(boom)

		var sign_node := MeshInstance3D.new()
		## Smaller than it was, and higher. At three metres wide and 6.4 up it was
		## a billboard you drove at rather than a sign you drove under: it filled a
		## third of the frame for the second before you passed it.
		sign_node.mesh = _box(2.3, 0.66, 0.18)
		sign_node.material_override = _mat(PINK)
		## HIGH ENOUGH TO PASS UNDER. At 4.15 the sign hung at the camera's own
		## eye height, so instead of sweeping up and out of the top of the frame
		## it slid across the middle of it, over the road you steer by. The
		## camera looks down about ten degrees and the frame reaches some
		## twenty-eight degrees above that, so a sign two and a half metres over
		## the lens leaves the top while it is still four metres away.
		sign_node.position = Vector3(float(side) * 0.3, 7.0, 0.0)
		furn.add_child(sign_node)

		## The label, so a station says what it is. `Label3D` is a billboarded
		## quad - no font atlas to build and no canvas to keep in step with the
		## world - and it is the only text in the 3D scene.
		var label := Label3D.new()
		label.text = "CANDLE"
		label.font_size = 72
		label.pixel_size = 0.006
		label.modulate = Color.WHITE
		if _font != null:
			label.font = _font
		label.outline_size = 18
		label.outline_modulate = Color(0.55, 0.03, 0.22)
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.rotation = Vector3(0, PI, 0)
		label.position = Vector3(float(side) * 0.3, 7.0, -0.12)
		furn.add_child(label)

		## THE WAX IS FLAT WITH THE ROAD. Read at 1080p: a pool is an area of
		## colour level with the surface, with no side wall and no rim. What
		## makes it read as liquid is what happens ON it - marbling, dimples and
		## a ring where the stream lands - and all of that is in `wax.gdshader`.
		##
		## This was a raised tub with a darker rim for one version, built off a
		## 360p frame where the pool's own shading was mistaken for a wall.
		## Slightly wider than half, so the two pools MEET. At exactly half
		## there is a white seam down the centre line, and the reference has
		## one continuous sheet of wax with two colours in it.
		var w := Tuning.ROAD_HALF_WIDTH * 1.04
		var wall := MeshInstance3D.new()   ## kept so the rig shape is unchanged
		wall.mesh = _box(0.01, 0.01, 0.01)
		wall.visible = false
		h.add_child(wall)
		var liquid := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2(w, Tuning.POOL_LENGTH)
		## Subdivided so the fragment shader has room to work and so the surface
		## can be displaced later without re-authoring the mesh.
		quad.subdivide_width = 8
		quad.subdivide_depth = 16
		liquid.mesh = quad
		liquid.material_override = _wax_material()
		## ABOVE THE STRIPES, and by a real margin. The road stripes are boxes
		## 0.06 tall sitting at y=0.02, so their tops are at 0.05 - a pool at
		## 0.03 has them standing PROUD of it, and the wax rendered as pink with
		## white rungs across it. It reads as a transparency or a z-fighting bug
		## and is neither: the stripes are simply taller than the wax is deep.
		liquid.position.y = 0.09
		h.add_child(liquid)

		# the machine over it
		var head := Node3D.new()
		head.position = Vector3(float(side) * 0.1, 2.6, -Tuning.POOL_LENGTH * 0.5 + 1.4)
		furn.add_child(head)

		## A LADLE, not a ball on a stick: an open bowl with a rim, wax visible
		## inside it, tipped so the stream leaves the LIP. A whole sphere with a
		## cylinder under its middle reads as a lollipop being waved, and a
		## stream leaving the centre of a sphere is leaking rather than pouring.
		var bowl := MeshInstance3D.new()
		bowl.mesh = _cyl(0.70, 0.34, 0.62, 14)
		## PALE ICE-BLUE and frosted, not chrome. Read at 1080p the bowl is
		## closer to frosted glass than to metal, and a mirror-bright ladle in a
		## flat-shaded world is the one object trying to be photographic.
		bowl.material_override = _mat(LADLE)
		head.add_child(bowl)
		var inner := MeshInstance3D.new()
		inner.mesh = _cyl(0.60, 0.30, 0.14, 14)
		inner.material_override = _mat(Color.WHITE)
		inner.position.y = 0.14
		head.add_child(inner)
		## THIN, PALE AND NEARLY VERTICAL, which is what the reference's stream
		## is. At 0.17-0.26 across and 2.6 long, hanging off a ladle tipped 0.62
		## rad, it swung out across the whole track and read as a gold baguette
		## lying over the runway - the single most conspicuous wrong thing in a
		## frame. Wax leaving a lip falls; it does not point where the lip points.
		var pour := MeshInstance3D.new()
		pour.mesh = _cyl(0.055, 0.085, 2.3, 8)
		pour.material_override = _mat(Color.WHITE)
		pour.position = Vector3(0.46, -1.28, 0.0)
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
			"node": h, "furn": furn, "sign": sign_node, "label": label,
			"wall": wall, "liquid": liquid,
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
	_font = load("res://assets/font/Fredoka-Bold.ttf") as FontFile

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
	_money_pill = _pill(Control.PRESET_TOP_RIGHT, Vector2(-40, 60), 44, true)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 520
	_toast.offset_left = -420
	_toast.offset_right = 420
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font != null:
		_toast.add_theme_font_override("font", _font)
	_toast.add_theme_font_size_override("font_size", 84)
	_toast.add_theme_color_override("font_color", Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", INK)
	_toast.add_theme_constant_override("outline_size", 18)
	_toast.modulate.a = 0.0
	_ui.add_child(_toast)

	_build_home()
	_build_ruler()
	_build_reward()
	_build_shop()
	_show_screens()


## A HUD PILL: a gold lozenge with a dark line round it and white bold text,
## which is what the reference has. Ours was white text floating on the sky.
##
## Returns the Label, because `_sync` sets `.text` on it every frame and the
## panel around it is scenery. The panel is a `PanelContainer` so it sizes
## itself to whatever the text grows to - a fixed-width pill clips "1,250 $" the
## first time the player has a good run.
func _pill(preset: int, offset: Vector2, font: int, note: bool = false) -> Label:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(preset)
	panel.position = offset
	if preset == Control.PRESET_TOP_RIGHT:
		panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif preset == Control.PRESET_CENTER_TOP:
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = PILL
	sb.border_color = INK
	sb.set_border_width_all(6)
	## A lozenge, not a rounded rectangle: the radius is half the height, so the
	## ends are semicircles however long the text gets.
	sb.set_corner_radius_all(int(font * 0.9))
	sb.content_margin_left = 34.0
	sb.content_margin_right = 34.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", sb)
	_ui.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	if note:
		## The little green banknote on the money pill. Drawn rather than
		## imported: it is thirty pixels wide on the phone, and at that size an
		## icon file is a dependency to keep in step for no visible gain.
		var chip := Control.new()
		chip.custom_minimum_size = Vector2(46, 34)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.draw.connect(_draw_note.bind(chip))
		row.add_child(chip)

	var l := Label.new()
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 10)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	return l


func _draw_note(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, INK)
	c.draw_rect(r.grow(-4.0), NOTE)
	var mid := r.size * 0.5
	c.draw_circle(mid, minf(r.size.x, r.size.y) * 0.22, Color(0.86, 0.96, 0.89))


## THE HOME SCREEN IS ON THE RUNWAY.
##
## Not a sheet over a paused game: the level is already built behind these cards
## and the first swipe starts it. The reference has a SHOP button on the right
## edge, two boost cards in the middle, and a swipe hint under them - and that
## is the whole of it.
func _build_home() -> void:
	_home = Control.new()
	_home.set_anchors_preset(Control.PRESET_FULL_RECT)
	## IGNORE on the container, STOP on each control.
	##
	## A full-rect panel that swallows input would eat the swipe that starts the
	## run - the swipe has to reach the world THROUGH this screen. So the
	## container is transparent to input and only the buttons take it.
	_home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_home)

	var shop := _button("SHOP", 40)
	shop.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	shop.position = Vector2(-260, -120)
	shop.custom_minimum_size = Vector2(200, 200)
	shop.pressed.connect(_on_shop)
	_home.add_child(shop)

	_boost_candle = _card("CANDLE", "EXTRA +1", PINK, Vector2(-330, 430))
	_boost_candle.pressed.connect(_on_boost_candles)
	_boost_cash = _card("CASH", "BONUS x1.5", NOTE, Vector2(30, 430))
	_boost_cash.pressed.connect(_on_boost_cash)

	var hint := Label.new()
	hint.text = "< SWIPE TO START >"
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.position = Vector2(0, 820)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style(hint, 40)
	_home.add_child(hint)


## THE SHOP SELLS SHOPS.
##
## The reference has no upgrade sheet - no list of stats with buy buttons
## anywhere in six levels of footage. What the player buys is a new SHOP, and a
## shop is a new station on the runway or a better product coming off it. The
## ladder lives in `shops.gd`; this only draws it.
func _build_shop() -> void:
	_shop = Control.new()
	_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop.visible = false
	_shop.draw.connect(_draw_shop_bg)
	_ui.add_child(_shop)

	var title := Label.new()
	title.text = "SHOP"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.position = Vector2(0, 90)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style(title, 96)
	_shop.add_child(title)

	## A SCROLL CONTAINER, and it has to be able to take a drag.
	##
	## The last game shipped a workshop that would not scroll, because the
	## world's own drag handler answered first and steered instead. Here the
	## steering lives in `_unhandled_input`, so a drag this container consumes
	## never reaches it - but only if the container is actually reachable, which
	## is what `the shop scrolls` asserts.
	_shop_scroll = ScrollContainer.new()
	_shop_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_scroll.offset_top = 230
	_shop_scroll.offset_bottom = -220
	_shop_scroll.offset_left = 50
	_shop_scroll.offset_right = -50
	_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	## A GODOT SCROLLCONTAINER DOES NOT SCROLL FROM A FINGER.
	##
	## Measured, because it is not written anywhere obvious: a mouse WHEEL
	## scrolls it, an `InputEventPanGesture` scrolls it, and an
	## `InputEventScreenDrag` - which is what a thumb on a phone produces -
	## moves it by exactly zero. `emulate_mouse_from_touch` does not save it
	## either, because a mouse DRAG is not a wheel.
	##
	## So a shop list on a phone would simply not move, and nothing about it
	## would look broken in the editor. The last game shipped a workshop that
	## would not scroll for a different reason; this is the same bug wearing a
	## different hat.
	_shop_scroll.gui_input.connect(_on_shop_drag)
	_shop.add_child(_shop_scroll)

	_shop_rows = VBoxContainer.new()
	_shop_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_rows.add_theme_constant_override("separation", 26)
	_shop_scroll.add_child(_shop_rows)

	var back := _button("BACK", 52)
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.grow_horizontal = Control.GROW_DIRECTION_BOTH
	back.position = Vector2(-190, -170)
	back.custom_minimum_size = Vector2(380, 120)
	back.pressed.connect(_close_shop)
	_shop.add_child(back)

	_build_shop_rows()


## One row per shop, built once. Rebuilding the list on every purchase would
## throw away the scroll position, which on a seven-rung ladder means the row
## you just bought jumps off the screen at the moment you tap it.
func _build_shop_rows() -> void:
	for entry in Shops.ALL:
		var row := PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		## IGNORE, so a drag that starts on a row reaches the scroll container.
		## A Control defaults to STOP, containers included, so every row would
		## otherwise swallow the gesture and the list would move only when the
		## finger happened to land in a gap between two of them.
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.94)
		sb.border_color = INK
		sb.set_border_width_all(5)
		sb.set_corner_radius_all(26)
		sb.content_margin_left = 26.0
		sb.content_margin_right = 26.0
		sb.content_margin_top = 20.0
		sb.content_margin_bottom = 22.0
		row.add_theme_stylebox_override("panel", sb)
		_shop_rows.add_child(row)

		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 20)
		row.add_child(line)

		var text := VBoxContainer.new()
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)

		var name_label := Label.new()
		name_label.text = String(entry.name)
		_style(name_label, 46)
		name_label.add_theme_color_override("font_color", INK)
		name_label.add_theme_constant_override("outline_size", 0)
		text.add_child(name_label)

		var blurb := Label.new()
		blurb.text = String(entry.blurb)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.custom_minimum_size = Vector2(520, 0)
		_style(blurb, 30)
		blurb.add_theme_color_override("font_color", Color(0.36, 0.34, 0.44))
		blurb.add_theme_constant_override("outline_size", 0)
		text.add_child(blurb)

		var buy := _button("%s $" % SimUtil.fmt(float(entry.price)), 38)
		buy.custom_minimum_size = Vector2(250, 110)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.pressed.connect(_on_buy.bind(String(entry.id)))
		line.add_child(buy)

		row.set_meta("buy", buy)
		row.set_meta("id", String(entry.id))


## Recomputed from the save on every open and after every purchase, so a row can
## never claim to be for sale when it is not.
func _refresh_shop() -> void:
	var owned: Array = _state.get("owned", [])
	for row in _shop_rows.get_children():
		var id := String(row.get_meta("id"))
		var buy: Button = row.get_meta("buy")
		var entry := Shops.by_id(id)
		if Shops.owns(owned, id):
			buy.text = "OWNED"
			buy.disabled = true
		elif Shops.can_buy(owned, sim.cash, id):
			buy.text = "%s $" % SimUtil.fmt(float(entry.price))
			buy.disabled = false
		else:
			## Locked and unaffordable look different on purpose: one is a
			## price you are saving for, the other is a rung you have not
			## reached, and a player who cannot tell them apart will save for
			## the wrong thing.
			var next := Shops.next_for(owned)
			var is_next := not next.is_empty() and String(next.id) == id
			buy.text = "%s $" % SimUtil.fmt(float(entry.price)) if is_next else "LOCKED"
			buy.disabled = true


## Drag anywhere on the list to scroll it. Only the buy buttons take a touch,
## so a drag that starts on a row reaches this.
func _on_shop_drag(event: InputEvent) -> void:
	var dy := 0.0
	if event is InputEventScreenDrag:
		dy = event.relative.y
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		dy = event.relative.y
	else:
		return
	_shop_scroll.scroll_vertical -= int(dy)
	_shop_scroll.accept_event()


func _on_buy(id: String) -> void:
	var owned: Array = _state.get("owned", [])
	if not Shops.can_buy(owned, sim.cash, id):
		return
	var entry := Shops.by_id(id)
	sim.cash -= float(entry.price)
	owned.append(id)
	_state.owned = owned
	_state.cash = sim.cash
	## The stats are DERIVED from what is owned, so this is the one write and
	## `_apply_save_to_sim` is the one read.
	var stats := Shops.stats_for(owned)
	for k in stats:
		_state[k] = stats[k]
	Save.store(_state)
	_apply_save_to_sim()
	_refresh_shop()
	_sync()


func _close_shop() -> void:
	_set_phase(Phase.HOME)


func _draw_shop_bg() -> void:
	_shop.draw_rect(Rect2(Vector2.ZERO, _shop.size), Color(0.129, 0.098, 0.271, 0.93))


## The money ruler: an absolute scale with your own best marked on it, which the
## finished batch climbs. Not a fraction of a target, and no stars.
func _build_ruler() -> void:
	_ruler = Control.new()
	_ruler.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ruler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ruler.draw.connect(_draw_ruler)
	_ruler.visible = false
	_ui.add_child(_ruler)


func _build_reward() -> void:
	_reward = Control.new()
	_reward.set_anchors_preset(Control.PRESET_FULL_RECT)
	## STOP, unlike the home screen: this one is a modal and nothing behind it
	## should be steerable while it is up.
	_reward.mouse_filter = Control.MOUSE_FILTER_STOP
	_reward.visible = false
	_reward.draw.connect(_draw_reward_bg)
	_ui.add_child(_reward)

	_reward_amount = Label.new()
	_reward_amount.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_reward_amount.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_reward_amount.position = Vector2(0, 420)
	_style(_reward_amount, 132)
	_reward.add_child(_reward_amount)

	_reward_best = Label.new()
	_reward_best.text = "NEW HIGH SCORE!"
	_reward_best.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_reward_best.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_reward_best.position = Vector2(0, 590)
	_style(_reward_best, 52)
	_reward_best.add_theme_color_override("font_color", PILL)
	_reward.add_child(_reward_best)

	## NO MULTIPLIER FAN. The reference's is a rewarded-video wheel, and this
	## game has no ads - a spinner that always lands on x1 is a worse screen
	## than no spinner. Gideon asked for the plain amount and a continue button.
	_reward_take = _button("TAKE", 56)
	_reward_take.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_reward_take.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_reward_take.position = Vector2(-230, -320)
	_reward_take.custom_minimum_size = Vector2(460, 130)
	_reward_take.pressed.connect(_take_reward)
	_reward.add_child(_reward_take)


## One place that decides what is on screen, driven by the phase.
##
## Every screen's visibility is set here on EVERY transition, rather than each
## handler turning off the one it knows about. A screen left visible by a
## transition nobody thought about is the classic version of this bug, and it
## cannot happen if the answer is recomputed from the phase.
## THE ONLY PLACE THE PHASE CHANGES, so it cannot change without the screens
## following it.
##
## Assigning `_phase` directly and calling `_show_screens()` next to it worked
## everywhere except `freeze()`, which set the phase to RUN and left the home
## screen drawn over the whole game. The visual check found it - the fraction of
## the upper frame that was still sky fell from 0.87 to 0.62 - and no model
## assertion could have, because every number was right and the picture was not.
func _set_phase(p: int) -> void:
	_phase = p
	_show_screens()


func _show_screens() -> void:
	if _home == null:
		return
	_home.visible = _phase == Phase.HOME
	_ruler.visible = _phase == Phase.RULER
	_reward.visible = _phase == Phase.REWARD
	_shop.visible = _phase == Phase.SHOP
	if _phase == Phase.SHOP:
		_refresh_shop()
	if _phase == Phase.REWARD:
		_reward_amount.text = "%s $" % SimUtil.fmt(_run_value)
		_reward_best.visible = _beat_best
		_reward_take.text = "TAKE %s" % SimUtil.fmt(_run_value)
	if _phase == Phase.HOME:
		_refresh_boosts()


func _refresh_boosts() -> void:
	_boost_candle.text = "CANDLE
EXTRA +1
%s $" % SimUtil.fmt(BOOST_PRICE)
	_boost_cash.text = "CASH
BONUS x1.5
%s $" % SimUtil.fmt(BOOST_PRICE)
	_boost_candle.disabled = sim.cash < BOOST_PRICE or sim.boost_candles > 0
	_boost_cash.disabled = sim.cash < BOOST_PRICE or sim.boost_cash > 1.0


func _on_boost_candles() -> void:
	if sim.cash < BOOST_PRICE or sim.boost_candles > 0:
		return
	sim.cash -= BOOST_PRICE
	sim.boost_candles += 1
	_state.cash = sim.cash
	Save.store(_state)
	## The boost changes what the batch STARTS as, so the level has to be laid
	## out again for it to be there when the run begins.
	##
	## AND THE SAVE HAS TO GO BACK ON AFTERWARDS. `Sim.restart` zeroes cash -
	## it is per-run state as far as the simulation is concerned - so without
	## this, buying a boost spent 500 and then wiped the rest of the player's
	## money on the way out. Anything that restarts a level owes it the save.
	sim.restart(sim.level)
	_apply_save_to_sim()
	_stand = 0.0
	_refresh_boosts()
	_sync()


func _on_boost_cash() -> void:
	if sim.cash < BOOST_PRICE or sim.boost_cash > 1.0:
		return
	sim.cash -= BOOST_PRICE
	sim.boost_cash = 1.5
	_state.cash = sim.cash
	Save.store(_state)
	_refresh_boosts()
	_sync()


func _on_shop() -> void:
	_set_phase(Phase.SHOP)


func _card(title: String, caption: String, tint: Color, at: Vector2) -> Button:
	var b := _button("%s
%s" % [title, caption], 38)
	b.set_anchors_preset(Control.PRESET_CENTER_TOP)
	b.grow_horizontal = Control.GROW_DIRECTION_BOTH
	b.position = at
	b.custom_minimum_size = Vector2(300, 340)
	var sb: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
	sb.bg_color = tint
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	_home.add_child(b)
	return b


## Every button in the game, so they cannot drift apart.
func _button(text: String, font: int) -> Button:
	var b := Button.new()
	b.text = text
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sb := StyleBoxFlat.new()
	sb.bg_color = PILL
	sb.border_color = INK
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(28)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 16.0
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, sb)
	_style(b, font)
	return b


func _style(c: Control, font: int) -> void:
	c.add_theme_font_size_override("font_size", font)
	c.add_theme_color_override("font_color", Color.WHITE)
	c.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	c.add_theme_color_override("font_outline_color", INK)
	c.add_theme_constant_override("outline_size", 10)
	if _font != null:
		c.add_theme_font_override("font", _font)


func _draw_gear() -> void:
	var c := Vector2(56, 56)
	_gear.draw_circle(c, 52, Color(1, 1, 1, 0.92))
	_gear.draw_arc(c, 52, 0.0, TAU, 40, Color(0.16, 0.05, 0.22), 6.0)
	_gear.draw_circle(c, 20, Color(0.48, 0.42, 0.55))
	for i in 6:
		var a := TAU * float(i) / 6.0
		_gear.draw_line(c + Vector2(cos(a), sin(a)) * 24.0,
			c + Vector2(cos(a), sin(a)) * 40.0, Color(0.48, 0.42, 0.55), 9.0)


## THE RULER IS ABSOLUTE MONEY with your own best marked on it in yellow.
##
## Not a fraction of a target and not a star rating - those were ours. What makes
## a level mean something in the reference is beating the number you got last
## time, and that only works if the scale is money you recognise.
func _draw_ruler() -> void:
	var size := _ruler.size
	var x := size.x * 0.62
	var top := size.y * 0.22
	var bottom := size.y * 0.76
	var span := bottom - top

	## The scale runs to whichever is larger, so a run that smashes the best is
	## still on the ruler and a first run has somewhere to climb to.
	var top_value: float = maxf(maxf(_run_value, _run_best), 1.0) * 1.25
	var bar := Rect2(Vector2(x, top), Vector2(74, span))
	_ruler.draw_rect(bar.grow(6.0), INK)
	_ruler.draw_rect(bar, Color(0.98, 0.98, 1.0))

	var ticks := 6
	for i in range(ticks + 1):
		var f := float(i) / float(ticks)
		var ty := bottom - span * f
		_ruler.draw_line(Vector2(x - 22, ty), Vector2(x, ty), INK, 5.0)
		if _font != null:
			_ruler.draw_string(_font, Vector2(x - 240, ty + 14),
				SimUtil.fmt(top_value * f), HORIZONTAL_ALIGNMENT_RIGHT, 220, 40, INK)

	## The climb, eased, so the last few hundred slow down as they arrive.
	var eased := 1.0 - pow(1.0 - _ruler_t, 3.0)
	var shown := _run_value * eased
	var fill := span * clampf(shown / top_value, 0.0, 1.0)
	_ruler.draw_rect(Rect2(Vector2(x + 4, bottom - fill), Vector2(66, fill)), NOTE)

	## THE BEST BAND GOES ON AFTER THE FILL. Drawn before it, the bar climbs over
	## the top of the one thing the whole screen is about - the mark you are
	## trying to beat - and it disappears at exactly the moment it starts to
	## matter. Its label sits clear of the bar on the left for the same reason.
	if _run_best > 0.0:
		var by := bottom - span * clampf(_run_best / top_value, 0.0, 1.0)
		_ruler.draw_rect(Rect2(Vector2(x - 26, by - 9), Vector2(132, 18)), PILL)
		_ruler.draw_rect(Rect2(Vector2(x - 26, by - 9), Vector2(132, 18)), INK, false, 4.0)
		if _font != null:
			_ruler.draw_string(_font, Vector2(x - 250, by - 16), "BEST",
				HORIZONTAL_ALIGNMENT_RIGHT, 220, 34, INK)

	var my := bottom - fill
	_ruler.draw_rect(Rect2(Vector2(x + 86, my - 30), Vector2(210, 60)), NOTE)
	_ruler.draw_rect(Rect2(Vector2(x + 86, my - 30), Vector2(210, 60)), INK, false, 5.0)
	if _font != null:
		_ruler.draw_string(_font, Vector2(x + 100, my + 16), SimUtil.fmt(shown),
			HORIZONTAL_ALIGNMENT_LEFT, 190, 44, Color.WHITE)


func _draw_reward_bg() -> void:
	_reward.draw_rect(Rect2(Vector2.ZERO, _reward.size), MODAL)


## The save is the source of truth for progress; the sim is where it is spent.
func _apply_save() -> void:
	sim.cash = float(_state.cash)
	sim.restart(int(_state.level))
	_apply_save_to_sim()


## Called after every `sim.restart`, because restart does not know about the
## save - and a level restarted without this quietly drops every upgrade the
## player has bought, which looks like the shop not working.
func _apply_save_to_sim() -> void:
	if _state.is_empty():
		return
	sim.cash = float(_state.cash)
	## DERIVED FROM WHAT IS OWNED, not read out of the save's own copies.
	## Those are still written so a downgrade does not lose everything, but
	## `Shops` is the source of truth - a stat stored beside the list of
	## shops is a second one, and the two drift the first time a rung is
	## inserted in the middle of the ladder.
	var stats := Shops.stats_for(_state.get("owned", []))
	sim.earn_level = int(stats.earn_level)
	sim.press_level = int(stats.press_level)
	sim.wrap_level = int(stats.wrap_level)
	sim.has_scent = bool(stats.has_scent)


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
	## HOME and REWARD do not advance the simulation, but they DO still draw:
	## the world is live behind both of them, which is most of why the reference
	## reads as one continuous place rather than as a game with menus over it.
	if _phase == Phase.RUN:
		sim.advance(dt)
	elif _phase == Phase.RULER:
		_ruler_t = minf(_ruler_t + dt, 1.0)
		_ruler.queue_redraw()
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
func _on_level_finished(value: float) -> void:
	_run_value = value
	_run_best = float(_state.best)
	_beat_best = value > _run_best
	_ruler_t = 0.0
	_set_phase(Phase.RULER)


## The ruler runs itself and then hands over; the reward screen waits for a tap.
##
## The climb is what makes the number mean something - the reference animates the
## batch up an absolute money scale past a yellow band at your own best - so it
## is on a timer rather than on a button. Being made to tap through an animation
## you have not finished watching is worse than either.
func _advance_interlude(dt: float) -> void:
	if _phase != Phase.RULER:
		return
	_interlude += dt
	if _interlude < RULER_SECONDS:
		return
	_interlude = 0.0
	_set_phase(Phase.REWARD)


## Taking the money is the only thing that banks it, and the only thing that
## moves the level on.
func _take_reward() -> void:
	if _phase != Phase.REWARD:
		return
	sim.cash += _run_value
	_state.cash = sim.cash
	_state.best = maxf(float(_state.best), _run_value)
	_state.level = sim.level + 1
	Save.store(_state)
	sim.restart(sim.level + 1)
	_apply_save_to_sim()
	_stand = 0.0
	_set_phase(Phase.HOME)
	_sync()


## The first swipe starts the run, which is the only tutorial the reference has.
func _start_run() -> void:
	if _phase != Phase.HOME:
		return
	_set_phase(Phase.RUN)


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
	_apply_save_to_sim()
	## A harness plays; it does not sit on the home screen waiting for a swipe.
	## Same simulation either way - HOME differs only in not calling advance -
	## so this is a starting phase, not a test-only code path.
	_set_phase(Phase.RUN)
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
	var eye := Vector3(sim.x * 0.55, 3.9 + tail * 0.16 + up,
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
				## One shard cluster and one cap cluster, at the same place. Two
				## instances for the whole hazard, where the pyramid version took ten.
				if nb < POOL:
					mb.set_instance_transform(nb, Transform3D(Basis.IDENTITY, Vector3(ox, 0.0, oz)))
					nb += 1
				if nk < POOL:
					mk.set_instance_transform(nk, Transform3D(Basis.IDENTITY, Vector3(ox, 0.0, oz)))
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
		## eleven metres back, so a station culled at the batch's own
		## position is still eleven metres in FRONT of the lens.
		##
		## The station is culled on its POOL, which is the last part of it to
		## leave the frame. The gantry over it goes separately, in `_dress_rig`,
		## the moment it is passed.
		if sz + Tuning.POOL_LENGTH * 0.5 < _cam_z or sz > sim.distance + 130.0:
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

		## The gantry goes as soon as the batch is through it. It is drawn from
		## the moment the station comes into range until then, so nothing pops
		## in ahead of the player; what it must not do is linger BEHIND them,
		## where a three-metre sign a few metres off the lens covers half the
		## road. One cull distance for both cannot work: the pool has to
		## outlast the batch that is still standing in it.
		var furn: Node3D = h.furn
		furn.visible = sz > sim.distance - 1.0

		h.sign.material_override = _mat(PINK)
		var label: Label3D = h.label
		label.text = String(k.label)
		var liq: MeshInstance3D = h.liquid
		liq.visible = kind != Stations.ROTATE
		var wax_mat: ShaderMaterial = liq.material_override
		wax_mat.set_shader_parameter("tint", col)
		## Only a wax or scent station is liquid. Glitter, the press and the gift
		## box get the same quad with the flow and the gloss taken out of it, so
		## it reads as a painted pad rather than as a puddle a bottle is standing
		## in.
		wax_mat.set_shader_parameter("flow_speed", 0.09 if liquid else 0.0)
		wax_mat.set_shader_parameter("gloss", 0.45 if liquid else 0.12)
		wax_mat.set_shader_parameter("bubble_scale", 0.9 if liquid else 0.0)
		## Where the stream is landing, in the quad's own space, and how long ago
		## - so the ring spreads from the pour rather than from the middle.
		if liquid:
			var head_local: Node3D = h.head
			wax_mat.set_shader_parameter("impact",
				Vector2(head_local.position.x * 2.0, head_local.position.z * 2.0))
			wax_mat.set_shader_parameter("impact_age", fposmod(sim.time * 1.1, 1.6))
		else:
			wax_mat.set_shader_parameter("impact_age", 99.0)

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
			## The stream is a PALE, part-transparent version of the wax, not a rope
			## of it at full strength: falling wax is thin enough to see through.
			var stream := _mat(col.lerp(Color.WHITE, 0.42))
			stream.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			stream.albedo_color.a = 0.78
			pour.material_override = stream
			# HELD, and tipped just enough to spill over the rim. A ladle that is
			# pouring barely moves; what moves is the wax.
			head.position.y = 2.55 + sin(beat) * 0.08
			head.rotation = Vector3(0, 0, 0.62 + sin(beat * 1.3) * 0.07)
			## Counter-rotate the stream out of the ladle's tilt so it falls
			## straight down. It is a child of the head so that it stays on the
			## LIP as the ladle rocks, which is right - but inheriting the tilt as
			## well pointed it sideways, and wax does not do that.
			pour.rotation = Vector3(0, 0, -head.rotation.z + 0.06)
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
		## THE FIRST SWIPE STARTS THE RUN, and it also steers - the reference
		## has no start button, and the swipe that begins a run is the same
		## gesture that moves the batch. Reaching here at all means no control
		## consumed it, which is what keeps a tap on a boost card from starting
		## the run - the bug that shipped twice on the last game.
		if _phase == Phase.HOME:
			_start_run()
		if _phase != Phase.RUN:
			return
		var dx: float = event.relative.x
		var span := float(get_viewport().get_visible_rect().size.x)
		sim.steer_to(sim.target_x + dx / span * Tuning.LANE_HALF_WIDTH * 3.4)


# --- helpers --------------------------------------------------------------

## One ShaderMaterial per pool, because each carries its own colour and its own
## impact point. The shader itself is shared.
func _wax_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/wax.gdshader")
	return m


## The toon material every MultiMesh uses.
##
## `ink_width` is where an inverted hull's `grow` used to be: a big prop wants a
## narrower band than a candle does, or the whole thing goes dark. Zero turns
## the line off, for things like the road stripes that are too thin to carry one.
func _toon(c: Color, ink_width: float, tinted: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/toon.gdshader")
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("ink", INK)
	m.set_shader_parameter("ink_width", ink_width)
	m.set_shader_parameter("use_instance_color", tinted)
	return m


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
func _mm(mesh: Mesh, c: Color, count: int, tinted: bool = false,
		ink: float = 0.30) -> MultiMeshInstance3D:
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
	mmi.material_override = _toon(c, ink, tinted)
	add_child(mmi)
	return mmi
