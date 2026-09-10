class_name Sim
extends RefCounted

## The whole game, with no renderer in it.
##
## `Sim` owns every number that decides what happens; the scene in `src/game/`
## reads those numbers and draws them, and never the other way round. Nothing in
## this file may reference a Node, a Viewport, an input event or a delta that
## came from a real frame.
##
## THE TWO AXES. Everything in the game is one of these:
##
##   - **How many candles.** Loose candles on the runway add one each; obstacles
##     knock them off the back of the batch.
##   - **What each one is worth.** The pools, and every candle carries its own
##     recipe - so the player's LINE decides which candles get which colour.
##
## THE TWO SECTIONS. A level runs flat until the ROTATE wall, where the whole
## batch stands up; after it the press and the gift station work on candles that
## are finally upright. `standing` is simulation state, not a rendering flourish:
## it is what the wall is for.

signal dipped(kind: int, x: float, z: float, colour: Color)
signal picked_up(x: float, z: float)
## Carries the AMOUNT, not just the place. What a note is worth is
## `CASH_VALUE` times the level's scale times the earn multiplier, so the
## renderer cannot work it out from a constant - and when it tried, the game
## told the player `+5 $` while the bank received several times that.
signal cash_taken(x: float, z: float, amount: float)
signal hit_obstacle(kind: String, x: float, z: float, lost: int)
signal stood_up(z: float)
signal level_finished(value: float)

var level: int = 1
var distance: float = 0.0
var x: float = 0.0
var target_x: float = 0.0
var over: bool = false
var time: float = 0.0
var cash: float = 0.0
var standing: bool = false

var lost: int = 0
var gained: int = 0
var dips: int = 0

var batch: Array[Candle] = []
var trail: Trail = Trail.new()

## Live entities, as plain dictionaries rather than nodes - a node here would
## drag the scene tree into the test runner.
var stations: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []
var loose: Array[Dictionary] = []
var notes: Array[Dictionary] = []

var _chunk_spawned: int = -1
var _station_seq: int = 0
var _positions: Array[Vector2] = []

## What the player has bought. Kept on the run because the shop is between runs
## and the simulation has to be able to start from nothing in a test.
var earn_level: int = 0
var press_level: int = 0
var wrap_level: int = 0
var has_scent: bool = false
var boost_candles: int = 0
var boost_cash: float = 1.0


func _init(start_level: int = 1) -> void:
	restart(start_level)


func restart(start_level: int = 1) -> void:
	level = start_level
	distance = 0.0
	x = 0.0
	target_x = 0.0
	over = false
	time = 0.0
	cash = 0.0
	standing = false
	lost = 0
	gained = 0
	dips = 0
	batch.clear()
	for i in Tuning.START_CANDLES + boost_candles:
		batch.append(Candle.make())
	trail.clear_to(0.0, 0.0)
	stations.clear()
	obstacles.clear()
	loose.clear()
	notes.clear()
	_chunk_spawned = -1
	_station_seq = 0
	trail.layout(count(), _positions)


func count() -> int:
	return batch.size()


## The finish line, in metres.
func finish_z() -> float:
	return Tuning.CHUNK * float(Tuning.CHUNKS_PER_LEVEL)


func advance(dt: float) -> void:
	if over:
		return
	time += dt

	distance += Tuning.FORWARD_SPEED * dt
	x = lerpf(x, target_x, SimUtil.smooth(Tuning.STEER_RATE, dt))
	x = clampf(x, -Tuning.LANE_HALF_WIDTH, Tuning.LANE_HALF_WIDTH)
	trail.push(x, distance)

	_spawn_ahead()
	var n := trail.layout(count(), _positions)
	_update_stations(n)
	_update_obstacles(n)
	_update_pickups(dt)
	_retire_passed()

	if distance >= finish_z():
		over = true
		level_finished.emit(appraise())


func steer_to(new_target_x: float) -> void:
	target_x = clampf(new_target_x, -Tuning.LANE_HALF_WIDTH, Tuning.LANE_HALF_WIDTH)


## Where each candle is right now. The renderer reads this; so does every
## collision check, which is what keeps the two from disagreeing.
func positions() -> Array[Vector2]:
	return _positions


func state() -> Dictionary:
	var st := stats()
	return {
		"level": level,
		"distance": snappedf(distance, 0.001),
		"x": snappedf(x, 0.001),
		"count": count(),
		"standing": standing,
		"colours": snappedf(float(st.colours), 0.001),
		"glitter": snappedf(float(st.glitter), 0.001),
		"pressed": st.pressed,
		"wrapped": st.wrapped,
		"worth": snappedf(batch_value(), 0.001),
		"cash": snappedf(cash, 0.001),
		"lost": lost,
		"gained": gained,
		"dips": dips,
		"stations": stations.size(),
		"obstacles": obstacles.size(),
		"loose": loose.size(),
		"notes": notes.size(),
		"over": over,
	}


# --- the batch ------------------------------------------------------------

func batch_value() -> float:
	var v := 0.0
	for c in batch:
		v += c.value()
	return v


func earn_multiplier() -> float:
	return (1.0 + float(earn_level) * 0.14) * boost_cash


## WHAT ONE NOTE ON THIS RUNWAY IS WORTH.
##
## The ONE place this is worked out. The price tag lying on the road shows it,
## the floating text when it is taken shows it, and `cash` receives it - three
## readings of one fact, which is the shape that drifts. It drifted the moment
## it existed in two places: the tag said `+5 $` from `CASH_VALUE` while the
## bank got `CASH_VALUE * scale_for(level) * earn_multiplier()`, so a player on
## level six with an earning shop was told five and paid many times it.
func note_value() -> float:
	return float(Tuning.CASH_VALUE) * Tuning.scale_for(level) * earn_multiplier()


## What the run is worth at the gift table.
## WHAT THIS RUN WAS WORTH. Not what the player has.
##
## `cash` is the notes picked up on THIS runway - `restart` zeroes it - and the
## bank lives outside the simulation entirely. It was seeded from the save for a
## while, and the result was that every run appraised the player's whole balance
## as if they had just earned it, and then paid it into the balance again. A
## bank of 5,000 went 24,528 -> 63,585 -> 141,699 over three runs of the same
## level. It also made the whole shop ladder affordable in under five runs,
## which is what the measurement was looking at when it found this.
func appraise() -> float:
	return batch_value() * Tuning.scale_for(level) * earn_multiplier() * Tuning.VALUE_SCALE + cash


func stats() -> Dictionary:
	var n := count()
	if n == 0:
		return {"colours": 0.0, "glitter": 0.0, "pressed": 0, "wrapped": 0,
			"scented": 0, "plain": 0}
	var col := 0.0
	var gl := 0.0
	var pressed := 0
	var wrapped := 0
	var scented := 0
	var plain := 0
	for c in batch:
		col += float(c.colour_count())
		gl += float(c.glitter)
		if c.mould > 0:
			pressed += 1
		if c.wrap > 0:
			wrapped += 1
		if c.scent > 0:
			scented += 1
		if c.layers.size() <= 1 and c.glitter == 0:
			plain += 1
	return {
		"colours": col / float(n), "glitter": gl / float(n),
		"pressed": pressed, "wrapped": wrapped, "scented": scented, "plain": plain,
	}


## Loose candles join the BACK of the batch, bare, and have to be taken through
## the pools like everything else.
func grow(n: int) -> int:
	var added := 0
	while batch.size() < Tuning.MAX_CANDLES and added < n:
		batch.append(Candle.make())
		added += 1
	return added


## Obstacles eat the TAIL, never the head.
##
## Losing the back rather than the front is the only version that reads
## correctly: the leader is the thing the thumb is steering, and having it
## vanish mid-corner feels like the game took the controls away, while the tail
## is exactly what the player failed to think about.
func shrink(n: int) -> int:
	var taken := mini(n, batch.size())
	for i in taken:
		batch.pop_back()
	return taken


# --- spawning -------------------------------------------------------------

func _spawn_ahead() -> void:
	var horizon := distance + 90.0
	var last_chunk := int(horizon / Tuning.CHUNK)
	while _chunk_spawned < last_chunk:
		_chunk_spawned += 1
		_spawn_chunk(_chunk_spawned)


func _spawn_chunk(c: int) -> void:
	if c < 2 or c > Tuning.CHUNKS_PER_LEVEL:
		return
	var z := float(c) * Tuning.CHUNK

	var slot := Stations.slot_for(c)
	if not slot.is_empty():
		_spawn_station(c, z + 6.0, slot)
		return

	var dens := clampf(0.7 + float(c) * 0.012, 0.0, 1.5) \
		* clampf(0.8 + float(level) * 0.07, 0.0, 1.7)

	# The pickup line is decided BEFORE the obstacles, so one can be planted on
	# it. That is the only place where the reward and the danger are in the same
	# spot, and it is what turns steering from "avoid things" into a decision.
	var has_cash := SimUtil.hash2(c, 913 + level) < Tuning.CASH_CHANCE
	var cash_x := Tuning.lane_x(SimUtil.hash2(c, 905 + level))
	var guarded := has_cash and SimUtil.hash2(c, 907 + level) < Tuning.GUARDED_CASH

	if c >= 5 and SimUtil.hash2(c, 91 + level) < Tuning.BARRIER_CHANCE * dens:
		var bn := 1 + int(SimUtil.hash2(c, 120 + level) * 2.2)
		for i in bn:
			obstacles.append({
				"kind": "barrier",
				"x": cash_x if (i == 0 and guarded) else Tuning.lane_x(SimUtil.hash2(c, 300 + i)),
				"z": z + 2.0 + float(i) * 3.6,
				"w": 0.95, "hit": false, "side": 0, "reach": 0.0, "phase": 0.0, "dir": 1,
			})

	if c >= 9 and SimUtil.hash2(c, 402 + level) < Tuning.ROLLER_CHANCE * dens:
		# Anchored at one rail and reaching PART WAY across, the way the
		# reference draws it. `x` and `w` are then just the centre and
		# half-width of what it covers, so the shared collision test needs to
		# know nothing about any of this - and the gap is on the far side by
		# construction rather than by luck.
		var side := 1 if SimUtil.hash2(c, 700 + level) > 0.5 else -1
		var reach := Tuning.LANE_HALF_WIDTH * (0.70 + SimUtil.hash2(c, 702 + level) * 0.40)
		obstacles.append({
			"kind": "roller", "side": side, "reach": reach,
			"x": float(side) * (Tuning.ROAD_HALF_WIDTH - reach * 0.5), "w": reach * 0.5,
			"z": z + 5.0 + SimUtil.hash2(c, 705) * 3.0,
			"hit": false, "phase": 0.0, "dir": 1,
		})

	if c >= 14 and SimUtil.hash2(c, 860 + level) < Tuning.SWEEPER_CHANCE * dens:
		# The one obstacle that MOVES, and its position is a function of
		# `distance` rather than of elapsed time. The same thing at a constant
		# speed, and unlike a clock it is reproducible, so the golden still
		# holds. Anything that decides *when* is simulation.
		obstacles.append({
			"kind": "sweeper", "x": 0.0, "w": 1.15,
			"z": z + 4.0 + SimUtil.hash2(c, 865) * 5.0,
			"hit": false, "side": 0, "reach": Tuning.LANE_HALF_WIDTH * 0.55,
			"phase": SimUtil.hash2(c, 870) * TAU,
			"dir": 1 if SimUtil.hash2(c, 875) > 0.5 else -1,
		})

	if SimUtil.hash2(c, 611 + level) < Tuning.loose_chance_for(level):
		# One or two early, more as the levels go on. A pile of six on chunk two
		# when the batch starts at one hands the player the whole run in the
		# first three seconds.
		var ln := 1 + int(SimUtil.hash2(c, 940) * 1.7) + level / 3
		var lx := Tuning.lane_x(SimUtil.hash2(c, 945 + level))
		var sweep := (SimUtil.hash2(c, 950) - 0.5) * 3.0
		for i in ln:
			var t := 0.5 if ln <= 1 else float(i) / float(ln - 1)
			loose.append({
				"x": clampf(lx + sweep * (t - 0.5) * 2.0,
					-Tuning.LANE_HALF_WIDTH, Tuning.LANE_HALF_WIDTH),
				"z": z + 2.0 + t * 8.0,
				"lie": (SimUtil.hash2(c, 970 + i) - 0.5) * 1.5,
				"taken": false,
			})

	if has_cash:
		var cn := 1 + int(SimUtil.hash2(c, 900) * 2.0)
		for i in cn:
			notes.append({"x": cash_x, "z": z + 3.0 + float(i) * 4.5, "taken": false})


func _spawn_station(c: int, z: float, slot: Dictionary) -> void:
	var wall := Stations.is_wall(slot)
	var left := _make_half(int(slot.a), c, 210)
	var right := _make_half(int(slot.b), c, 340)
	# Two wax pools side by side are never the same colour: a choice between two
	# identical things is not a choice, and the reference's own advice ("dunk all
	# of your candles in both") only means anything if they differ.
	if int(left.kind) == Stations.WAX and int(right.kind) == Stations.WAX \
			and int(left.wax) == int(right.wax):
		var pal := Stations.palette_for(level)
		right.wax = pal[(pal.find(int(left.wax)) + 1) % pal.size()]
	if not wall and SimUtil.hash2(c, 455 + level) > 0.5:
		var t := left
		left = right
		right = t
	stations.append({
		"z": z, "left": left, "right": right, "wall": wall,
		"done": false, "touched": false,
	})


func _make_half(kind: int, c: int, salt: int) -> Dictionary:
	# The Scent Shop has to be bought before its station appears, which is the
	# reference's progression model - money buys stations rather than
	# percentages. Until then the slot falls back to a wax pool, so the gantry
	# is never half empty.
	if kind == Stations.SCENT and not has_scent:
		kind = Stations.WAX
	_station_seq += 1
	var pal := Stations.palette_for(level)
	return {
		"kind": kind,
		"id": _station_seq,
		"wax": pal[int(SimUtil.hash2(c, salt + level) * float(pal.size())) % pal.size()],
		"mould": clampi(1 + press_level, 1, Wax.MOULDS.size() - 1),
		"wrap": clampi(1 + wrap_level, 1, Wax.WRAPS.size() - 1),
	}


# --- the stations acting on the batch -------------------------------------

func _update_stations(n: int) -> void:
	for st in stations:
		if absf(float(st.z) - distance) > Tuning.POOL_LENGTH + 30.0:
			continue

		# THE WALL. It spans the whole track, so crossing it is not a choice:
		# the batch stands up here and only here, once per level.
		if bool(st.wall):
			if not bool(st.done) and absf(distance - float(st.z)) < 1.2:
				st.done = true
				standing = true
				stood_up.emit(float(st.z))
			continue

		var z0 := float(st.z) - Tuning.POOL_LENGTH * 0.5
		var z1 := float(st.z) + Tuning.POOL_LENGTH * 0.5
		for i in n:
			var p := _positions[i]
			if p.y < z0 or p.y > z1:
				continue
			if absf(p.x) > Tuning.ROAD_HALF_WIDTH:
				continue
			var half: Dictionary = st.left if p.x < 0.0 else st.right
			var c := batch[i]
			if c.mark == int(half.id):
				continue
			c.mark = int(half.id)
			if _apply(half, c):
				dips += 1
				st.touched = true
				dipped.emit(int(half.kind), p.x, p.y, _half_colour(half))


func _apply(half: Dictionary, c: Candle) -> bool:
	match int(half.kind):
		Stations.WAX:
			return c.dip(int(half.wax))
		Stations.GLITTER:
			return c.add_glitter(1)
		Stations.PRESS:
			return c.press(int(half.mould))
		Stations.WRAP:
			return c.wrap_in(int(half.wrap))
		Stations.SCENT:
			return c.add_scent()
	return false


func _half_colour(half: Dictionary) -> Color:
	match int(half.kind):
		Stations.WAX:
			return Wax.colour(int(half.wax))
		Stations.GLITTER:
			return Color(1.0, 0.831, 0.161)
		Stations.PRESS:
			return Color(0.545, 0.878, 1.0)
		Stations.WRAP:
			var w: Dictionary = Wax.WRAPS[int(half.wrap)]
			return w.col
		Stations.SCENT:
			return Color(0.847, 0.706, 1.0)
	return Color.WHITE


# --- obstacles ------------------------------------------------------------

func _update_obstacles(n: int) -> void:
	for o in obstacles:
		# Set before the culling below, because the renderer reads `x` and a
		# sweeper that only moved while it was collidable would visibly jump the
		# moment it stopped being one.
		if String(o.kind) == "sweeper":
			o.x = float(o.reach) * sin(float(o.phase) + distance * 0.26 * float(o.dir))
		if bool(o.hit) or float(o.z) > distance + 4.0:
			continue
		var reach := float(o.w) + Tuning.COLLIDE_TOLERANCE
		var struck := false
		for i in n:
			var p := _positions[i]
			if absf(p.y - float(o.z)) < 0.85 and absf(p.x - float(o.x)) < reach:
				struck = true
				break
		if not struck:
			continue
		o.hit = true
		var base := Tuning.BARRIER_TAKE
		if String(o.kind) == "roller":
			base = Tuning.ROLLER_TAKE
		elif String(o.kind) == "sweeper":
			base = Tuning.SWEEPER_TAKE
		var took := shrink(Tuning.cap_take(base, count()))
		lost += took
		hit_obstacle.emit(String(o.kind), float(o.x), float(o.z), took)


# --- pickups --------------------------------------------------------------

func _update_pickups(dt: float) -> void:
	var mag := Tuning.MAGNET_RADIUS
	for c in loose:
		if bool(c.taken):
			continue
		var dz := float(c.z) - distance
		if dz < -8.0 or dz > 16.0:
			continue
		var dx := float(c.x) - x
		if dx * dx + dz * dz < mag * mag:
			var k := SimUtil.smooth(11.0, dt)
			c.x = lerpf(float(c.x), x, k)
			c.z = lerpf(float(c.z), distance, k)
			var ndx := float(c.x) - x
			var ndz := float(c.z) - distance
			if ndx * ndx + ndz * ndz < 0.7:
				c.taken = true
				if grow(1) > 0:
					gained += 1
				picked_up.emit(float(c.x), float(c.z))

	for b in notes:
		if bool(b.taken):
			continue
		var bdz := float(b.z) - distance
		if bdz < -8.0 or bdz > 16.0:
			continue
		if absf(bdz) < 1.0 and absf(float(b.x) - x) < mag:
			b.taken = true
			var paid := note_value()
			cash += paid
			cash_taken.emit(float(b.x), float(b.z), paid)


## Entities behind the batch are dropped. Without this the arrays grow for the
## whole level and every collision check gets slower as the run goes on - which
## reads as "the game slows down near the end" and gets blamed on rendering.
func _retire_passed() -> void:
	var tail := Trail.back_for(count() - 1)
	var cutoff := distance - tail - 14.0
	obstacles = obstacles.filter(func(o): return float(o.z) > cutoff)
	loose = loose.filter(func(c): return float(c.z) > cutoff)
	notes = notes.filter(func(b): return float(b.z) > cutoff)
	stations = stations.filter(func(s): return float(s.z) > cutoff - Tuning.POOL_LENGTH)
