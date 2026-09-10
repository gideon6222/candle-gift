class_name Sfx
extends Node

## The whole sound of the game, synthesised at boot. No audio files.
##
## Two reasons, and the second is the real one.
##
## Every sound here is a short percussive blip a few hundred samples long. A
## folder of .wav files for those is a folder to keep in step with the code that
## names them, and a rename that misses one is a silent failure - the sound
## simply stops happening and nothing reports it.
##
## And a sound that is a FUNCTION can take arguments. `dip` is pitched by which
## layer the candle is on, so a batch weaving through four pools plays a rising
## figure rather than the same click four times; `pickup` climbs with a streak.
## That is not something a fixed sample can do without a folder of variants.
##
## Built as `AudioStreamWAV` at load rather than pushed through an
## `AudioStreamGenerator` every frame: the generator needs a filled buffer on a
## deadline and drops out if a frame runs long, which on a phone is exactly when
## the interesting things are happening.

const RATE := 22050
const VOICES := 8

## Every sound the game makes, so a caller cannot invent one silently.
const DIP := "dip"
const PICKUP := "pickup"
const CASH := "cash"
const HIT := "hit"
const STAND := "stand"
const BUY := "buy"
const DENY := "deny"
const FINISH := "finish"
## Imported, CC0, from Kenney's Interface and Impact packs. A produced sample
## beats a sine blip for a tap or a knock, and unlike the dip it does not need
## to change pitch with game state - which is the one thing a fixed sample
## cannot do and is why the dip ladder stays synthesised.
const TAP := "tap"
const CONFIRM := "confirm"
const DENY_UI := "deny_ui"
const BACK := "back"
const KNOCK := "knock"

var enabled := true
var music_enabled := true

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	build()
	## The preference may have been set before this node was in the tree - a
	## headless harness boots the scene explicitly and `_ready` has not run
	## yet - so the music is started here rather than there.
	set_music(music_enabled)


## Idempotent and callable before the first frame, for the same reason
## `_ensure_booted` is: a headless harness adds this node and uses it in the
## same call, and `_ready` has not run yet.
func build() -> void:
	if not _streams.is_empty():
		return

	## A DIP PER LAYER. The pitch rises with how many colours are already on the
	## candle, which turns weaving through four pools into a phrase.
	for layer in Tuning.MAX_LAYERS:
		var f := 320.0 * pow(1.09, float(layer))
		_streams["%s_%d" % [DIP, layer]] = _make(0.10, f, 0.55, 0.0, 2.4)

	_streams[PICKUP] = _make(0.09, 660.0, 0.42, 320.0, 3.0)
	_streams[CASH] = _make(0.13, 880.0, 0.40, 520.0, 2.2)
	## Noisy and low: the one sound that is bad news.
	_streams[HIT] = _make(0.20, 150.0, 0.62, -60.0, 1.6, 0.55)
	_streams[STAND] = _make(0.34, 220.0, 0.50, 520.0, 1.2)
	_streams[BUY] = _make(0.26, 520.0, 0.48, 480.0, 1.5)
	## A flat, short, dull thud. "You cannot do that" has to be unmistakable and
	## must not sound like a smaller version of success.
	_streams[DENY] = _make(0.11, 150.0, 0.45, -40.0, 3.0, 0.20)
	_streams[FINISH] = _make(0.50, 440.0, 0.52, 660.0, 1.0)

	## The imported half. Loaded by name so a missing file is a missing SOUND
	## rather than a crash - and `the sounds that are imported actually loaded`
	## in the smoke suite is what turns that into a failure instead of silence.
	for pair in [[TAP, "tap"], [CONFIRM, "confirm"], [DENY_UI, "deny"],
			[BACK, "back"], [KNOCK, "knock"]]:
		var res := load("res://assets/sfx/%s.ogg" % pair[1])
		if res != null:
			_streams[pair[0]] = res

	## A MUSIC BED, so the switch that turns music off controls something.
	##
	## A settings panel with a switch for a feature that does not exist is worse
	## than a panel with one fewer switch: the player turns it off, nothing
	## changes, and now they do not trust the other one either.
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.stream = _make_bed()
	_music.volume_db = -14.0
	add_child(_music)

	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_voices.append(p)


## One tone: a sine with a little of its own square in it, swept in frequency and
## faded out by a power curve.
##
## `decay` above 1 is percussive - most of the sound is in the first tenth of it.
## `noise` mixes in a deterministic hash rather than `randf`, because two runs of
## the same level should sound the same; the audio is cosmetic, but "cosmetic" is
## not a reason to make a recording of a run unreproducible.
func _make(seconds: float, freq: float, gain: float, sweep: float,
		decay: float, noise: float = 0.0) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f: float = freq + sweep * t
		phase += TAU * f / float(RATE)
		var s := sin(phase)
		s = s * 0.82 + signf(s) * 0.18
		if noise > 0.0:
			s = lerpf(s, SimUtil.hash2(i, 91) * 2.0 - 1.0, noise)
		var env := pow(1.0 - t, decay)
		var v := int(clampf(s * env * gain, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)

	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## AN UPBEAT LOOP, and the last one was genuinely creepy.
##
## Gideon's words. The old bed was a root, a fifth and an octave held together
## with a slow swell - which is not a bad synth, it is a drone, and a drone in a
## minor-leaning set is how you write dread. Three things fix it and none of them
## is fidelity:
##
##   - A MAJOR PROGRESSION with a real cadence: I - V - vi - IV, the four chords
##     every cheerful pop song is built from.
##   - MOVEMENT. A bouncing arpeggio at a quaver, so something happens eight
##     times a bar instead of once every four.
##   - A PULSE. A soft kick on the beat. A loop with no rhythm floats; the thing
##     that makes music feel happy rather than ambient is that it has a tempo you
##     can nod to.
##
## 120 BPM, sixteen bars of two seconds, thirty-two seconds. Still generated
## rather than imported, because there is nothing to import: Kenney's audio packs
## are the CC0 library this project uses and they have jingles, not loops.
func _make_bed() -> AudioStreamWAV:
	const BPM := 120.0
	const BEAT := 60.0 / BPM
	const BARS := 16
	var bar_seconds := BEAT * 4.0

	## I - V - vi - IV in C, as semitone offsets from the root of each chord, and
	## the arpeggio walks root-third-fifth-octave up and back down.
	var roots: Array[float] = [261.63, 392.00, 440.00, 349.23]   # C, G, A, F
	var steps: Array[float] = [1.0, 1.25, 1.5, 2.0, 1.5, 1.25]   # major triad, up and down

	var n := int(RATE * bar_seconds * float(BARS))
	var data := PackedByteArray()
	data.resize(n * 2)
	var arp_phase := 0.0
	var bass_phase := 0.0
	var pad_phase := 0.0

	for i in n:
		var t := float(i) / float(RATE)
		var bar := int(t / bar_seconds) % 4
		var root: float = roots[bar]
		var in_bar := fposmod(t, bar_seconds)

		## The arpeggio: a new note every quaver, each one plucked.
		var eighth := BEAT * 0.5
		var step_i := int(in_bar / eighth) % steps.size()
		var into := fposmod(in_bar, eighth) / eighth
		arp_phase += TAU * root * 2.0 * steps[step_i] / float(RATE)
		## A short percussive envelope per note is what makes it bounce; held, the
		## same notes are a drone again.
		var pluck := pow(1.0 - into, 2.2)
		var arp := sin(arp_phase) * pluck * 0.34

		## The bass: the chord root, an octave down, held for the bar.
		bass_phase += TAU * root * 0.5 / float(RATE)
		var bass := sin(bass_phase) * 0.30

		## A pad underneath, quiet, for warmth.
		pad_phase += TAU * root * 1.5 / float(RATE)
		var pad := sin(pad_phase) * 0.10

		## The kick, on every beat. A sine sweeping down fast is a kick drum.
		var into_beat := fposmod(t, BEAT) / BEAT
		var kick := sin(TAU * (52.0 + 60.0 * pow(1.0 - into_beat, 3.0)) * t)
		kick *= pow(1.0 - into_beat, 7.0) * 0.42

		var v := arp + bass + pad + kick
		## Fade the very ends into each other, or the loop clicks.
		var edge := minf(1.0, minf(t, float(n) / float(RATE) - t) / 0.25)
		data.encode_s16(i * 2, int(clampf(v * edge * 0.62, -1.0, 1.0) * 32767.0))

	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	w.data = data
	return w


func set_music(on: bool) -> void:
	music_enabled = on
	## `play()` errors with "Playback can only happen when a node is inside
	## the scene tree" otherwise, and the flag above is enough: `_ready` calls
	## this again once it is. The error was printed by a suite that reported
	## itself as passing, which is its own small lesson.
	if _music == null or not _music.is_inside_tree():
		return
	if on and not _music.playing:
		_music.play()
	elif not on and _music.playing:
		_music.stop()


func play(name: String, pitch: float = 1.0) -> void:
	if not enabled:
		return
	## `AudioStream`, not `AudioStreamWAV`: half of these are imported .ogg
	## now, and typing this to the synthesised class silently refused to
	## play every one of them.
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		return
	## ROUND-ROBIN, and it is why there are eight of them. A single player
	## restarted on every event cuts its own tail off, and a batch crossing a
	## pool fires one dip per candle in the same frame - thirty of them, of
	## which the player should hear a chord rather than the last one.
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.4, 2.5)
	p.play()


## Pitched by how many colours the candle already wears.
func play_dip(layer: int) -> void:
	play("%s_%d" % [DIP, clampi(layer, 0, Tuning.MAX_LAYERS - 1)])


func names() -> Array:
	return _streams.keys()
