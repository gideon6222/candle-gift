class_name Settings
extends RefCounted

## PREFERENCES ARE NOT PROGRESS, and they do not share a file.
##
## The pause screen offers to erase your progress next to switches that control
## sound, and that promise only holds if the two are separate things. Wiping the
## save must not silence the game, and turning the music off must not be able to
## touch a single coin.

const PATH := "user://candlegift.settings.v1.json"

## Sound is a switch. MUSIC IS A CHOICE: 0 is off, and 1..N pick a track.
##
## It is a choice because the person who has to live with it is the only one who
## can judge it. Two generated beds were written for this game - one came back
## "creepy" and its replacement came back "chirpy" - and neither verdict was
## available to whoever wrote them. Four CC0 loops now ship with the game and the
## pause panel cycles them, which turns a taste question into a button.
const DEFAULTS := {
	"sound": true,
	"music_track": 1,
}


static func load_state() -> Dictionary:
	return Store.read(PATH, DEFAULTS)


static func store(state: Dictionary) -> void:
	Store.write(PATH, DEFAULTS, state)


static func wipe() -> void:
	Store.erase(PATH)
