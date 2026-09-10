extends RefCounted

## Design tests: assertions about *intent* rather than about values.
##
## A snapshot of the constants would fix the numbers and say nothing about what
## they are for. Everything here would still pass if every number moved, and
## fails only if a change breaks something the game is supposed to be about.


func test_the_steerable_band_fits_inside_the_road(t: TestHarness) -> void:
	## Anything the player must reach or dodge is placed inside the band a thumb
	## can cross, never across the width of the road mesh - or there are pickups
	## that cannot be reached and hazards that cannot be avoided.
	t.gt(Tuning.ROAD_HALF_WIDTH, Tuning.LANE_HALF_WIDTH,
		"the road must be wider than the lane the player steers in")
	for u in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var x := Tuning.lane_x(u)
		t.ok(absf(x) <= Tuning.LANE_HALF_WIDTH + 1e-6,
			"lane_x(%f) placed outside the steerable band" % u)


func test_a_pool_is_longer_than_the_batch_is_deep(t: TestHarness) -> void:
	## Otherwise a pool cannot get the whole batch in even standing still, and
	## the back of a long batch can never be dipped at all.
	var deepest := Trail.back_for(Tuning.MAX_CANDLES - 1)
	t.gt(Tuning.POOL_LENGTH, deepest * 0.55,
		"a pool (%.1f) must be comparable to the batch depth (%.1f)"
			% [Tuning.POOL_LENGTH, deepest])


func test_a_pool_is_short_enough_that_one_line_misses_the_other(t: TestHarness) -> void:
	## If a pool were long enough to cover the whole batch twice over, weaving
	## would be free and holding a line would collect everything anyway.
	t.lt(Tuning.POOL_LENGTH, Trail.back_for(Tuning.MAX_CANDLES - 1) * 1.2,
		"a pool must not be able to swallow the whole batch")


func test_the_wall_divides_the_level_into_two_real_sections(t: TestHarness) -> void:
	## Not a boundary two chunks from the end, and not one two chunks in.
	var c := Tuning.ROTATE_CHUNK
	t.gt(float(c), Tuning.CHUNKS_PER_LEVEL * 0.25,
		"the flat section must be long enough to matter")
	t.lt(float(c), Tuning.CHUNKS_PER_LEVEL * 0.75,
		"and so must the standing one")


func test_the_stations_before_the_wall_are_all_wax(t: TestHarness) -> void:
	## A press cannot stamp a candle lying on its side, and a bow cannot be seen
	## on one. Everything that needs a standing candle belongs after the wall.
	var wall := Tuning.ROTATE_CHUNK
	for slot in Stations.SLOTS:
		var c := int(slot.c)
		for k in [int(slot.a), int(slot.b)]:
			if c < wall:
				t.ok(k in [Stations.WAX, Stations.GLITTER, Stations.SCENT],
					"chunk %d is before the wall and holds %s"
						% [c, Stations.KINDS[k].n])
			elif c > wall:
				t.ok(k != Stations.ROTATE,
					"chunk %d holds a second ROTATE" % c)


func test_there_is_exactly_one_wall(t: TestHarness) -> void:
	## Twice in a level and it is a power-up again.
	var walls := 0
	for slot in Stations.SLOTS:
		if Stations.is_wall(slot):
			walls += 1
	t.eq(walls, 1, "a level has exactly one section boundary")


func test_no_level_offers_the_core_colour_at_a_pool(t: TestHarness) -> void:
	## Cream is the candle's own core and `dip` refuses a colour already on top,
	## so a cream pool is a dead station that reads on screen only as a batch
	## that stubbornly stays beige.
	for i in Stations.PALETTES.size():
		var pal: Array = Stations.PALETTES[i]
		t.ok(not (Wax.CREAM in pal), "palette %d offers CREAM" % i)
		t.gt(float(pal.size()), 2.0, "palette %d is too small to weave with" % i)


func test_every_palette_can_actually_weave(t: TestHarness) -> void:
	## At least one pair in each palette has to read as two colours, or the
	## contrast bonus can never be earned on that level.
	for i in Stations.PALETTES.size():
		var pal: Array = Stations.PALETTES[i]
		var any := false
		for a in pal:
			for b in pal:
				if a != b and Wax.reads_as_two(int(a), int(b)):
					any = true
		t.ok(any, "palette %d has no two colours that read apart" % i)


func test_loose_candles_get_more_plentiful_with_the_level(t: TestHarness) -> void:
	## Thirty candles is somewhere to get to, not somewhere to start.
	t.lt(Tuning.loose_chance_for(1), Tuning.loose_chance_for(4),
		"level 4 must be more generous than level 1")
	t.ok(Tuning.loose_chance_for(30) <= Tuning.LOOSE_MAX,
		"and it must level off rather than run away")


func test_the_batch_can_never_be_wiped_out_by_one_hit(t: TestHarness) -> void:
	for n in [1, 2, 3, 5, 10, 30]:
		t.lt(float(Tuning.cap_take(9, n)), float(n) if n > 1 else 2.0,
			"a hit on a batch of %d took all of it" % n)


func test_a_level_is_a_sensible_length(t: TestHarness) -> void:
	var s := Tuning.level_seconds(1)
	t.gt(s, 20.0, "a level under twenty seconds is a loading screen")
	t.lt(s, 60.0, "and over a minute is a commute")


func test_the_star_bands_are_a_real_ladder(t: TestHarness) -> void:
	t.eq(Tuning.STAR_AT.size(), 3, "three stars")
	for i in range(1, Tuning.STAR_AT.size()):
		t.gt(float(Tuning.STAR_AT[i]), float(Tuning.STAR_AT[i - 1]),
			"the star thresholds must ascend")
	t.eq(Tuning.stars_for(0.0, 100.0), 0, "nothing earns nothing")
	t.eq(Tuning.stars_for(1000.0, 100.0), 3, "a great run earns all three")


func test_the_denominations_are_the_reference_s_own_tags(t: TestHarness) -> void:
	## `REFERENCE.md` records three values read off price tags lying on the
	## track: `5 $`, `154 $`, `610 $`. The tiers exist to reproduce those, so
	## the assertion is against the observed numbers rather than against the
	## multipliers - a multiplier is an implementation of this, not the point.
	##
	## EACH AGAINST THE LEVEL IT WAS ACTUALLY OBSERVED AT. The three tags come
	## off different frames of a walkthrough covering several levels, so they are
	## not one level's price list: `5 $` is early footage, the bigger two are
	## later. The first draft of this asserted all three at level ten and failed
	## on tier 0 reading 25 - which was the test being right and the comment in
	## `Tuning` being wrong.
	t.gt(Tuning.scale_for(10), 1.0, "level 10 has no scaling, so this proves nothing")
	for row in [[1, 0, 5.0], [10, 1, 154.0], [10, 2, 610.0]]:
		var sim := Sim.new(int(row[0]))
		var tier := int(row[1])
		var want := float(row[2])
		var got := sim.note_value(tier)
		## Within 5%, because the multipliers are round numbers and the observed
		## values were read off a video frame.
		t.lt(absf(got - want) / want, 0.05,
			"tier %d at level %d reads %d, but the reference's tag says %d"
				% [tier, int(row[0]), int(got), int(want)])


func test_a_bigger_tag_is_always_worth_more(t: TestHarness) -> void:
	## A ladder, not a set. If two tiers ever paid the same the player would be
	## choosing between a hazard and no hazard for no reason.
	var sim := Sim.new(1)
	for i in Tuning.CASH_TIERS.size() - 1:
		t.gt(sim.note_value(i + 1), sim.note_value(i) * 1.5,
			"tier %d pays %d and tier %d pays %d - not enough between them"
				% [i, int(sim.note_value(i)), i + 1, int(sim.note_value(i + 1))])


func test_every_big_tag_is_behind_a_hazard(t: TestHarness) -> void:
	## THE MECHANIC. Money is meant to be a decision rather than something driven
	## over, and the whole of that rests on the big tags never lying in the open.
	##
	## Played rather than reasoned about: the tier is decided at spawn from the
	## same hash that decides the guard, and a test that re-derived it here would
	## agree with a broken spawner. So play levels and look at what is on the
	## ground - if a tier ever appears without an obstacle near it, the rule has
	## been lost.
	var seen := {0: 0, 1: 0, 2: 0}
	var unguarded_big := 0
	for level in [1, 3, 6, 10]:
		var sim := Sim.new(level)
		while not sim.over:
			sim.advance(1.0 / 30.0)
			for b in sim.notes:
				## ONLY TAGS THE PLAYER CAN STILL GO FOR. A tag behind the batch
				## is not a decision any more, and the first draft failed on
				## exactly that: the barrier sits a metre nearer than its tag, so
				## it is retired one frame earlier, and for that frame a note
				## fourteen metres behind the batch has no obstacle beside it.
				## That is a real transient and it is not the rule being broken.
				if float(b.z) < sim.distance:
					continue
				var tier := int(b.get("tier", 0))
				seen[tier] = int(seen[tier]) + 1
				if tier == 0:
					continue
				var near := false
				for o in sim.obstacles:
					if absf(float(o.z) - float(b.z)) < 14.0:
						near = true
						break
				if not near:
					unguarded_big += 1
	## The fixture has to contain the thing it is about, or it passes by absence.
	t.gt(float(seen[1]), 0.0, "no middle tag appeared at all across four levels")
	t.gt(float(seen[2]), 0.0, "no big tag appeared at all across four levels")
	t.eq(unguarded_big, 0, "a tag above the small one was lying in open road")


func test_the_small_tag_is_still_most_of_the_money_on_the_ground(t: TestHarness) -> void:
	## The denominations must not turn every note into an event. The big tag is
	## worth having because it is rare; if a third of the tags were big, money
	## would swamp the batch again - which is exactly what the first attempt did,
	## taking idling from 0 stars to 2.
	var small := 0
	var big := 0
	for level in [1, 3, 6, 10]:
		var sim := Sim.new(level)
		var counted := {}
		while not sim.over:
			sim.advance(1.0 / 30.0)
			for b in sim.notes:
				var key := "%.1f" % float(b.z)
				if counted.has(key):
					continue
				counted[key] = true
				if int(b.get("tier", 0)) == 0:
					small += 1
				else:
					big += 1
	t.gt(float(small + big), 20.0, "too few notes spawned to say anything")
	t.lt(float(big) / float(small + big), 0.25,
		"%d of %d tags are above the small one" % [big, small + big])
