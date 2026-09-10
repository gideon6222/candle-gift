extends RefCounted

## Behaviour of the simulation, tested by playing it - with no window, no GPU
## and no scene tree, in milliseconds.


static func _play(policy: String, level: int = 1) -> Dictionary:
	return Policies.play(policy, level)


func test_a_level_starts_with_one_candle(t: TestHarness) -> void:
	## A batch is something built over a run, not something handed out. At eight
	## the first thirty seconds were free.
	var s := Sim.new(1)
	t.eq(s.count(), 1, "exactly one candle to start with")
	t.eq(s.standing, false, "and it is lying down")


func test_a_level_ends_and_is_worth_something(t: TestHarness) -> void:
	var r := _play(Policies.GATHER)
	t.ok(bool(r.over), "the level finishes")
	t.gt(float(r.value), 0.0, "and pays something")
	t.gt(float(r.seconds), 20.0, "a level is a real length of time")
	t.lt(float(r.seconds), 60.0, "and not an endurance test")


func test_collecting_grows_the_batch(t: TestHarness) -> void:
	var r := _play(Policies.GATHER)
	t.gt(float(r.gained), 0.0, "loose candles are collected")
	t.gt(float(r.count), 1.0, "and the batch is bigger than it started")


func test_the_batch_never_exceeds_what_can_be_drawn(t: TestHarness) -> void:
	## The renderer pools to MAX_CANDLES. A batch that outgrows it would be a
	## HUD promising candles nothing draws.
	for lvl in [1, 4, 8]:
		var r := _play(Policies.GATHER, lvl)
		t.ok(int(r.count) <= Tuning.MAX_CANDLES,
			"level %d ended with %d candles" % [lvl, int(r.count)])


func test_the_wall_stands_the_batch_up_exactly_once(t: TestHarness) -> void:
	## The section boundary, and the reason ROTATE is not a pickup. Whatever the
	## player does, they cross it - so a level always ends standing.
	for policy in Policies.ALL:
		var r := _play(policy)
		t.ok(bool(r.standing), "%s ends the level standing up" % policy)


func test_the_batch_is_lying_down_before_the_wall(t: TestHarness) -> void:
	var s := Sim.new(1)
	var wall_z := float(Tuning.ROTATE_CHUNK) * Tuning.CHUNK + 6.0
	while s.distance < wall_z - 6.0 and not s.over:
		s.advance(1.0 / 60.0)
	t.ok(not s.standing, "still flat approaching the wall")
	while s.distance < wall_z + 4.0 and not s.over:
		s.advance(1.0 / 60.0)
	t.ok(s.standing, "and standing just past it")


func test_obstacles_take_candles_and_dodging_keeps_them(t: TestHarness) -> void:
	var idle := _play(Policies.IDLE)
	var dodge := _play(Policies.DODGE)
	t.gt(float(idle.lost), float(dodge.lost) - 0.001,
		"never steering must not lose fewer candles than dodging")


func test_an_obstacle_can_never_empty_a_small_batch(t: TestHarness) -> void:
	## With a batch that starts at one, a flat cost of three is the end of the
	## run before the player has touched anything.
	t.eq(Tuning.cap_take(3, 1), 1, "one candle loses one")
	t.eq(Tuning.cap_take(3, 2), 1, "two lose one")
	t.eq(Tuning.cap_take(3, 4), 2, "four lose two")
	t.eq(Tuning.cap_take(3, 30), 3, "and a full batch pays the flat cost")


func test_weaving_the_pools_beats_only_collecting(t: TestHarness) -> void:
	## THE test. If weaving does not out-earn simply collecting then steering
	## through a station does nothing, every pool is a thing that happens to
	## you, and the game is a screensaver.
	var gather := _play(Policies.GATHER)
	var weave := _play(Policies.WEAVE)
	t.gt(float(weave.value), float(gather.value) * 1.4,
		"weaving made %d, gathering %d" % [int(weave.value), int(gather.value)])
	## And it shows up as MORE CANDLES TREATED, not as more colours on each
	## one. Colours-per-candle is the tempting measure and it is the wrong
	## one: driving a single line straight through a pair of pools puts the
	## SAME candles through both, so a policy that never weaves can score a
	## high average on a small batch. Weaving spreads the batch across both
	## pools, which is worth more in total and shows up as treatments landed.
	t.gt(float(weave.dips), float(gather.dips) * 1.3,
		"weaving landed %d treatments, gathering %d"
			% [int(weave.dips), int(gather.dips)])


func test_a_pool_treats_the_candles_standing_in_it(t: TestHarness) -> void:
	## Not the whole batch. A station that treats everything regardless of where
	## it is removes all player input from the quality axis - and measured on the
	## sibling build, that produced an IDENTICAL per-candle value across every
	## way of playing.
	##
	## Asserted as a COMPARISON rather than against an absolute. Holding the left
	## rail and holding the right rail cross different pools, so the two lines
	## must produce different batches; if they do not, the pools are not places.
	## The absolute version of this test ("one line cannot collect every colour")
	## was simply wrong - a level offers three colours and one line can meet all
	## three across four stations.
	var left := _hold(-Tuning.LANE_HALF_WIDTH)
	var right := _hold(Tuning.LANE_HALF_WIDTH)
	t.gt(float(left.dips), 0.0, "holding a line still dips something")
	t.ok(left.recipe != right.recipe,
		"two different lines produced the same batch: %s vs %s"
			% [str(left.recipe), str(right.recipe)])


## Drive one whole first section pinned to one side, and report what came out.
static func _hold(lane: float) -> Dictionary:
	var s := Sim.new(1)
	s.grow(11)
	var wall_z := float(Tuning.ROTATE_CHUNK) * Tuning.CHUNK
	while s.distance < wall_z - 12.0 and not s.over:
		s.steer_to(lane)
		s.advance(1.0 / 60.0)
	var recipe := PackedInt32Array()
	for c in s.batch:
		recipe.append(c.layers.size() * 10 + c.glitter)
	return {"dips": s.dips, "recipe": recipe}


func test_every_station_kind_fires_in_a_real_level(t: TestHarness) -> void:
	## A mechanic whose condition can never be true fails as ABSENCE - no error,
	## nothing missing on screen, the game simply plays differently than it
	## reads. That is the one failure mode playtesting cannot see.
	var s := Sim.new(1)
	s.has_scent = true
	s.restart(1)
	var kinds := {}
	var mem := {}
	while not s.over:
		Policies.steer(Policies.WEAVE, s, mem)
		for st in s.stations:
			kinds[int(st.left.kind)] = true
			kinds[int(st.right.kind)] = true
		s.advance(1.0 / 60.0)
	for k in [Stations.WAX, Stations.GLITTER, Stations.PRESS,
			Stations.WRAP, Stations.ROTATE, Stations.SCENT]:
		t.ok(kinds.has(k), "%s never appeared in a whole level" % Stations.KINDS[k].n)


func test_two_pools_side_by_side_are_never_the_same_colour(t: TestHarness) -> void:
	## A choice between two identical things is not a choice.
	for lvl in [1, 2, 3, 4]:
		var s := Sim.new(lvl)
		while not s.over:
			for st in s.stations:
				if int(st.left.kind) == Stations.WAX and int(st.right.kind) == Stations.WAX:
					t.ok(int(st.left.wax) != int(st.right.wax),
						"level %d had a pair of identical pools" % lvl)
			s.advance(1.0 / 30.0)


func test_a_level_replays_identically(t: TestHarness) -> void:
	## Every spawn decision is keyed on (chunk, level) through the hash, so
	## level 3 is the same level 3 on any device, every time.
	var a := _play(Policies.WEAVE, 3)
	var b := _play(Policies.WEAVE, 3)
	t.dict_eq(b, a, "the same policy on the same level must play out identically")


func test_two_levels_are_different_runways(t: TestHarness) -> void:
	var a := _play(Policies.WEAVE, 1)
	var b := _play(Policies.WEAVE, 2)
	t.ok(float(a.worth) != float(b.worth), "level 2 must not be a copy of level 1")


func test_the_trail_lags_and_a_longer_batch_lags_further(t: TestHarness) -> void:
	## The mechanic the game turns on: the back of the batch is still going
	## where the front went a second ago.
	var s := Sim.new(1)
	s.grow(20)
	for i in 200:
		s.steer_to(0.0)
		s.advance(1.0 / 60.0)
	for i in 30:
		s.steer_to(Tuning.LANE_HALF_WIDTH)
		s.advance(1.0 / 60.0)
	var p := s.positions()
	t.gt(p[0].x, 1.0, "the leader has committed to the swerve")
	t.lt(p[p.size() - 1].x, p[0].x - 0.5,
		"and the tail is still on the old line")
	t.gt(p[0].y, p[p.size() - 1].y, "the back is behind the front")


func test_positions_are_what_collides(t: TestHarness) -> void:
	## What you see is what collides: one array, read by the renderer and by
	## every collision check.
	var s := Sim.new(1)
	s.grow(9)
	s.advance(1.0 / 60.0)
	t.eq(s.positions().size(), s.count(), "one position per candle, always")


## WHAT A RUN IS WORTH MUST NOT DEPEND ON WHAT THE PLAYER ALREADY HAS.
##
## `appraise()` adds `cash`, and `cash` is the notes picked up on THIS runway.
## For a while the bank was seeded into it from the save, so every run appraised
## the player's whole balance as if they had just earned it - and the reward
## screen then paid that into the balance again. A bank of 5,000 went 24,528 ->
## 63,585 -> 141,699 over three runs of the same level.
##
## The obvious assertion does NOT catch this. "the bank went up by the amount
## the reward screen said" is true either way, because both sides inflate
## together: the screen says R + bank, and the bank goes up by R + bank. The
## only thing that separates them is playing the same level twice with different
## amounts of money in the bank and demanding the same answer.
func test_a_runs_value_does_not_depend_on_the_bank(t: TestHarness) -> void:
	var poor := Policies.play(Policies.WEAVE, 1)

	var rich := Sim.new(1)
	rich.cash = 50000.0        ## as if a bank had been seeded into the run
	var mem := {}
	var step := 1.0 / 60.0
	for i in int(round((Tuning.level_seconds(1) + 3.0) / step)):
		if rich.over:
			break
		Policies.steer(Policies.WEAVE, rich, mem)
		rich.advance(step)

	## The rich run keeps the 50,000 it was handed - `appraise` adds `cash` and
	## that is correct for notes - so the difference between the two is exactly
	## the money that was put in, and nothing else.
	t.approx(rich.appraise() - 50000.0, float(poor.value), 1.0,
		"a run was worth more because the player already had money")


## And restarting clears it, so nothing carries from one runway to the next.
func test_restart_clears_the_runs_cash(t: TestHarness) -> void:
	var s := Sim.new(1)
	s.cash = 1234.0
	s.restart(1)
	t.approx(s.cash, 0.0, 0.001, "restarting a level kept the last run's notes")
