extends SceneTree

## Entry point for the pure tests.
##
##   godot --headless --script res://test/run_tests.gd
##
## Nothing loaded here touches a Node, a viewport or an input event, so this
## runs in a container with no GPU and no display in about a second. The scene
## is exercised separately by run_smoke.gd, which is slower and catches a
## different class of bug.


## THE SUITES ARE ENUMERATED, NOT LISTED.
##
## A hand-written list is a second place to remember, and the last game on these
## notes proved what that costs: nine tests were added, the list was not, and
## the runner cheerfully reported "65 passing" for a suite that was never run at
## all. A test that does not run is worse than a test that fails.
##
## So: every `test_*.gd` in this directory, sorted, and an assertion that there
## were any.
func _initialize() -> void:
	var suites := []
	var names := []
	var dir := DirAccess.open("res://test/")
	if dir != null:
		var files := dir.get_files()
		files.sort()
		for f in files:
			# .gd in the editor, .gd.remap once exported
			var base := f.trim_suffix(".remap")
			if not base.begins_with("test_") or not base.ends_with(".gd"):
				continue
			names.append(base)
			suites.append(load("res://test/" + base).new())
	if suites.is_empty():
		printerr("no test_*.gd suites were found in res://test/ - the runner found nothing to run")
		quit(1)
		return
	print("  suites: %s" % ", ".join(names))
	var code := TestHarness.run_all(suites)
	quit(code)
