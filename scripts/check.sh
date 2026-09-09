#!/usr/bin/env bash
# Everything, in the order that fails fastest.
#
#   scripts/check.sh
#
# The visual pass needs a GPU and is therefore NOT in CI - see NOTES.md. It is
# the local gate: run this, not `run_tests.gd` alone, before committing.
set -u
GODOT="${GODOT:-/c/Users/gideo/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
fail=0

step () {
	local name="$1"; shift
	local out
	out=$("$@" 2>&1 | tr -d '\r')
	# AN ENGINE ERROR IS A FAILURE, even when every assertion passed.
	#
	# The suite printed "Playback can only happen when a node is inside the
	# scene tree" and reported itself green in the same breath. An error nobody
	# has to act on is an error everyone learns to scroll past, and the next one
	# under it is the real one.
	if [ $? -ne 0 ] || echo "$out" | grep -qE "FAILED|SCRIPT ERROR|Parse Error|^ERROR:"; then
		echo "FAIL  $name"
		echo "$out" | grep -E "FAIL|ERROR" | head -12
		fail=1
	else
		echo "ok    $name  $(echo "$out" | grep -oE '[0-9]+ assertions[^,]*' | tail -1)"
	fi
}

step "pure    " "$GODOT" --path . --headless --script res://test/run_tests.gd
step "smoke   " "$GODOT" --path . --headless --script res://test/run_smoke.gd
step "visual  " "$GODOT" --path . --resolution 460x996 --script res://test/run_visual.gd
step "size    " "$GODOT" --path . --headless --script res://scripts/check_size.gd

exit $fail
