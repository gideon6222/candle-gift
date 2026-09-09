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
