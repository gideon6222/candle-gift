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
	if [ $? -ne 0 ] || echo "$out" | grep -q "FAILED\|SCRIPT ERROR\|Parse Error"; then
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
