class_name Settings
extends RefCounted

## PREFERENCES ARE NOT PROGRESS, and they do not share a file.
##
## The pause screen offers to erase your progress next to switches that control
## sound, and that promise only holds if the two are separate things. Wiping the
## save must not silence the game, and turning the music off must not be able to
## touch a single coin.

const PATH := "user://candlegift.settings.v1.json"

## Both default to ON. A switch that defaults off reads as broken.
const DEFAULTS := {
	"sound": true,
	"music": true,
}


static func load_state() -> Dictionary:
	return Store.read(PATH, DEFAULTS)


static func store(state: Dictionary) -> void:
	Store.write(PATH, DEFAULTS, state)


static func wipe() -> void:
	Store.erase(PATH)
