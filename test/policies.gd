class_name Policies
extends RefCounted

## Scripted players.
##
## These are not test fixtures. They are **the definition of "playing well"** -
## the thing every balance number in the game is measured against - and that is
## why they live in the repo rather than in a session. On the sibling build `par`
## was once set from a policy typed into a browser console whose lookahead was
## slightly longer than the committed one; it scored 65% higher and the constant
## went in 44% too high. Nobody could have caught that by reading the number.
##
## One policy per way of failing:
##
##   IDLE    touches nothing - proves that not playing earns nothing
##   DODGE   only avoids hazards - protects a batch it never builds
##   GATHER  only collects - builds a batch it never improves
##   WEAVE   dodges, then sweeps both pools, then collects - the whole game
##
## **The pair that proves a decision exists must differ in exactly one thing.**
## GATHER and WEAVE share all their code except the pool sweep, so the gap
## between their scores is a claim about the GAME rather than about the bots.

const IDLE := "idle"
const DODGE := "dodge"
const GATHER := "gather"
const WEAVE := "weave"

const ALL := [IDLE, DODGE, GATHER, WEAVE]


static func steer(name: String, s: Sim, mem: Dictionary) -> void:
	match name:
		IDLE:
			pass
		DODGE:
			if not _dodge(s):
				s.steer_to(0.0)
		GATHER:
			if not _gather(s):
				s.steer_to(0.0)
		WEAVE:
			if _dodge(s):
				return
			if _sweep(s, mem):
				return
			if not _gather(s):
				s.steer_to(0.0)


## Steers to whichever edge is further from the nearest thing in front.
## Deliberately crude: a policy with cleverness in it becomes a second thing
## that can change, and then a golden failure means "the bot got better" as
## often as "the game changed".
static func _dodge(s: Sim) -> bool:
	var best := INF
	var bx := 0.0
	for o in s.obstacles:
		if bool(o.hit):
			continue
		var dz := float(o.z) - s.distance
		if dz <= 0.0 or dz > 15.0:
			continue
		if dz < best:
			best = dz
			bx = float(o.x)
	if best == INF:
		return false
	var c := Tuning.LANE_HALF_WIDTH
	s.steer_to(-c if absf(bx + c) > absf(bx - c) else c)
	return true


## THE ONE THAT MATTERS. Sweeps left and right across a station so different
## candles land in each of its two pools, which is what the reference's own
## strategy guide tells players to do.
static func _sweep(s: Sim, mem: Dictionary) -> bool:
	for st in s.stations:
		if bool(st.wall):
			continue
		if absf(float(st.z) - s.distance) > Tuning.POOL_LENGTH * 0.75:
			continue
		var flip: int = int(mem.get("flip", 0)) + 1
		mem["flip"] = flip
		var c := Tuning.LANE_HALF_WIDTH * 0.75
		s.steer_to(-c if (flip / 4) % 2 == 1 else c)
		return true
	return false


static func _gather(s: Sim) -> bool:
	var best := INF
	var bx := 0.0
	for b in s.notes:
		if bool(b.taken):
			continue
		var dz := float(b.z) - s.distance
		if dz > 0.0 and dz < 14.0 and dz < best:
			best = dz
			bx = float(b.x)
	for c in s.loose:
		if bool(c.taken):
			continue
		var dz2 := float(c.z) - s.distance
		if dz2 > 0.0 and dz2 < 14.0 and dz2 < best:
			best = dz2
			bx = float(c.x)
	if best == INF:
		return false
	s.steer_to(bx)
	return true


## Play one whole level with one policy and hand back the final state, plus the
## readings a balance pass wants that the golden does not carry.
## `owned` is the list of SHOP IDS the player has bought, so a policy can be
## measured as a player who owns things rather than only as a fresh install.
##
## Every number in NOTES.md was measured with this empty, which was right when
## there was nothing to buy - but "the ladder is priced sensibly" is not a
## question the no-upgrade case can answer at all.
static func play(name: String, level: int = 1, seconds: float = 0.0,
		owned: Array = []) -> Dictionary:
	var s := Sim.new(level)
	if not owned.is_empty():
		var stats := Shops.stats_for(owned)
		s.earn_level = int(stats.earn_level)
		s.press_level = int(stats.press_level)
		s.wrap_level = int(stats.wrap_level)
		s.has_scent = bool(stats.has_scent)
		## After the stats, because the batch and the station palettes are
		## laid out from them - a scent station only exists on a runway
		## built by a player who owns the scent shop.
		s.restart(level)
	var mem := {}
	var step := 1.0 / 60.0
	var limit := seconds if seconds > 0.0 else Tuning.level_seconds(level) + 3.0
	var n := int(round(limit / step))
	for i in n:
		if s.over:
			break
		steer(name, s, mem)
		s.advance(step)
	var out := s.state()
	out["seconds"] = snappedf(s.time, 0.001)
	out["value"] = snappedf(s.appraise(), 0.001)
	## Normalised by the level's own price scale, so six levels can be averaged.
	out["norm"] = snappedf(s.appraise() / Tuning.scale_for(level), 0.001)
	out["stars"] = Tuning.stars_for(
		s.appraise(), Tuning.PAR * Tuning.scale_for(level))
	return out
