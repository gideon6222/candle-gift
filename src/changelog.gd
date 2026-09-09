class_name Changelog
extends RefCounted

## What changed, in the player's terms.
##
## The build stamp answers "did my update land". It cannot answer "what is
## actually different", which after a few sessions of work is the question that
## matters more - and a commit log is the wrong shape for it, being written for
## whoever maintains the code.
##
## Rules for entries: describe what the player can now do or see, not what was
## refactored; one line each; newest first.

const VERSION := "0.1.0"

const RELEASES := [
	{
		"version": "0.1.0",
		"date": "2026-09-09",
		"title": "The candle factory, rebuilt native",
		"notes": [
			"Steer one batch of candles down a factory line. Drag anywhere to move.",
			"You start with ONE candle. Loose candles on the runway are how a batch gets built, and they are scarce early.",
			"Wax lies in tubs across half the track, so which candles get which colour depends on where each one was as the batch snaked over it. The line you steer is the whole decision.",
			"Halfway down, a ROTATE wall spans the track and stands the whole batch upright. There is no way past it.",
			"Standing, the press stamps the candles into fluted, twisted and star shapes one at a time, and the gift station ties a bow on each.",
			"Red X walls, spiked rollers on a post, and a salmon bar that slides across knock candles off the back.",
			"Sell the batch at the end of a level and carry the money on to the next one.",
		],
	},
]
