extends SceneTree

## A balance probe, not a test. **Nothing here can fail.**
##
##   godot --headless --script res://test/run_probe.gd
##
## `PAR` is set from the MEAN over several levels, never from level one: a
## single procedural level swings a policy enormously on layout luck, and a
## constant calibrated against one draw is a constant calibrated against
## nothing. Run this, read the table, write the numbers into NOTES.md beside
## the constant they set.

const LEVELS := 6


func _initialize() -> void:
	var means := {}
	print("")
	print("  value per level, normalised by the level's own price scale")
	for policy in Policies.ALL:
		var line := "  %-9s" % policy
		var total := 0.0
		for lvl in range(1, LEVELS + 1):
			var r := Policies.play(policy, lvl)
			var norm := float(r.norm)
			total += norm
			line += "%8d" % int(norm)
		means[policy] = total / float(LEVELS)
		print(line + "   mean %6d" % int(means[policy]))

	print("")
	print("  at PAR = %d, the means land on:" % int(Tuning.PAR))
	for policy in Policies.ALL:
		print("    %-9s %6d   %d stars" % [
			policy, int(means[policy]),
			Tuning.stars_for(float(means[policy]), Tuning.PAR)])

	print("")
	print("  level 1 in detail")
	for policy in Policies.ALL:
		var r := Policies.play(policy, 1)
		print("    %-9s candles %2d  colours %.2f  glitter %.2f  dips %3d  lost %2d  gained %2d  value %6d" % [
			policy, int(r.count), float(r.colours), float(r.glitter),
			int(r.dips), int(r.lost), int(r.gained), int(r.value)])

	print("")
	print("  the golden, for pasting into test_golden.gd")
	for policy in Policies.ALL:
		var r := Policies.play(policy, 1)
		var parts := PackedStringArray()
		for k in r.keys():
			var v: Variant = r[k]
			if v is bool:
				parts.append('"%s": %s' % [k, "true" if v else "false"])
			elif v is float:
				parts.append('"%s": %s' % [k, str(v)])
			else:
				parts.append('"%s": %s' % [k, str(v)])
		print('	"%s": {%s},' % [policy, ", ".join(parts)])
	print("")
	quit(0)
