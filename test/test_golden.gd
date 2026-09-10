extends RefCounted

## THE important one.
##
## The simulation is deterministic given a level: spawning is keyed on
## (chunk, level) through the hash, nothing consults `randf()` or a real clock,
## and the one moving obstacle takes its position from `distance` rather than
## from elapsed time. So a whole level produces the same numbers on every
## machine, every time.
##
## That makes a golden over the WHOLE GAME possible, which is a far stronger
## safety net than testing any single function - and it is what makes a large
## refactor safe to attempt at all. Record it before changing anything.
##
## Four runs are recorded, not one, and the set is the point. A change that
## moves only some of them says something a single golden could not:
##
##   - IDLE alone moves        -> spawning changed
##   - DODGE but not IDLE      -> steering or collision changed
##   - GATHER but not DODGE    -> pickups changed
##   - WEAVE but not GATHER    -> the stations changed
##
## The numbers were recorded, not designed. If a deliberate balance change moves
## them, re-record in the same commit and say so in the message. A change to
## rendering, layout, input or the build must not touch them at all - if it
## does, something has leaked out of `src/game/` into `src/sim/`.

const GOLDEN := {
"idle": {"level": 1, "distance": 408.058, "x": 0.0, "count": 11, "standing": true, "colours": 2.545, "glitter": 1.0, "pressed": 8, "wrapped": 11, "worth": 1684.275, "cash": 70.0, "lost": 3, "gained": 13, "dips": 52, "stations": 1, "obstacles": 3, "loose": 2, "notes": 0, "over": true, "seconds": 35.483, "value": 120.528, "norm": 120.528, "stars": 0},
"dodge": {"level": 1, "distance": 408.058, "x": -2.894, "count": 9, "standing": true, "colours": 2.889, "glitter": 0.889, "pressed": 9, "wrapped": 9, "worth": 2686.001, "cash": 65.0, "lost": 3, "gained": 11, "dips": 55, "stations": 1, "obstacles": 3, "loose": 2, "notes": 0, "over": true, "seconds": 35.483, "value": 145.58, "norm": 145.58, "stars": 1},
"gather": {"level": 1, "distance": 408.058, "x": -1.137, "count": 6, "standing": true, "colours": 3.333, "glitter": 1.667, "pressed": 4, "wrapped": 6, "worth": 2720.82, "cash": 95.0, "lost": 12, "gained": 17, "dips": 67, "stations": 1, "obstacles": 3, "loose": 2, "notes": 0, "over": true, "seconds": 35.483, "value": 176.625, "norm": 176.625, "stars": 1},
"weave": {"level": 1, "distance": 408.058, "x": -2.894, "count": 12, "standing": true, "colours": 2.917, "glitter": 3.0, "pressed": 12, "wrapped": 12, "worth": 13088.494, "cash": 80.0, "lost": 3, "gained": 14, "dips": 132, "stations": 1, "obstacles": 3, "loose": 2, "notes": 0, "over": true, "seconds": 35.483, "value": 472.655, "norm": 472.655, "stars": 2},
}


func test_a_whole_level_is_unchanged(t: TestHarness) -> void:
	for policy in Policies.ALL:
		var expected: Dictionary = GOLDEN[policy]
		if expected.is_empty():
			continue
		var actual := Policies.play(policy, 1)
		t.dict_eq(actual, expected, "%s played level 1 differently" % policy)


## The four policies must not collapse into each other.
##
## A golden pins the numbers; this pins the SHAPE, and it is the one that keeps
## meaning something after a re-record. If the policy that reads the level ever
## stops beating the one that ignores it, the game has lost its decision - and
## no amount of matching numbers would show that.
func test_the_policies_still_separate(t: TestHarness) -> void:
	var v := {}
	for policy in Policies.ALL:
		v[policy] = float(Policies.play(policy, 1).value)
	t.gt(v[Policies.WEAVE], v[Policies.GATHER] * 1.4,
		"weaving (%d) must clearly beat gathering (%d)"
			% [int(v[Policies.WEAVE]), int(v[Policies.GATHER])])
	t.gt(v[Policies.GATHER], v[Policies.IDLE] * 1.15,
		"gathering (%d) must beat doing nothing (%d)"
			% [int(v[Policies.GATHER]), int(v[Policies.IDLE])])
