class_name Trail
extends RefCounted

## The recorded path, and the batch that lags behind it.
##
## **This is the mechanic the game turns on.** The leader is where the thumb is;
## candle `i` sits `i * TRAIL_GAP` back ALONG THE RECORDED PATH, not behind the
## leader in a straight line. So a long batch has to be steered early, because
## the back of it is still going where the front went a second ago.
##
## The reference's guide is describing exactly this: *"as your candle stack gets
## longer, you need to be aware of everything happening in front of you, and
## sometimes you need to start moving well before an obstacle is in reach."* It
## is also what makes a bigger batch a TRADE rather than free.
##
## Two consequences that are easy to lose:
##
##   - **Obstacles and pools test every candle, not the leader.** Otherwise the
##     trail is decoration and a long batch is strictly better than a short one.
##   - **The spacing is the same lying down and standing up.** It was tighter
##     standing for a while, and that split the game in two: the simulation
##     lays candles out at `TRAIL_GAP` to decide what a pool dips and what an
##     obstacle clips, while the renderer drew them somewhere else. Six percent
##     is not much, but "what you see is not what collides" has no small version.

var _x := PackedFloat32Array()
var _z := PackedFloat32Array()
var _n := 0
var _head := 0


func _init() -> void:
	_x.resize(Tuning.TRAIL_SAMPLES)
	_z.resize(Tuning.TRAIL_SAMPLES)


func clear_to(x: float, z: float) -> void:
	_n = 0
	_head = 0
	push(x, z)


func size() -> int:
	return _n


## Record where the leader is. Samples closer than a millimetre are dropped:
## without that the ring buffer fills with noise and silently shortens how far
## back it can remember, which silently shortens the maximum batch.
func push(x: float, z: float) -> void:
	if _n > 0:
		var i := _head - 1
		if i < 0:
			i += Tuning.TRAIL_SAMPLES
		if absf(_z[i] - z) < 0.02 and absf(_x[i] - x) < 0.02:
			return
	_x[_head] = x
	_z[_head] = z
	_head = (_head + 1) % Tuning.TRAIL_SAMPLES
	_n = mini(_n + 1, Tuning.TRAIL_SAMPLES)


## How far back candle `i` sits along the path.
static func back_for(i: int) -> float:
	return float(i) * Tuning.TRAIL_GAP


## The point `back` metres behind the leader, measured along the recorded path.
##
## Asking for more than the trail remembers returns the oldest point rather than
## extrapolating - at the start of a level the whole batch is legitimately
## stacked on the seed point, and inventing positions there would make it
## visibly explode outward over the first half second, which is the first thing
## a player ever sees.
func sample_back(back: float) -> Vector2:
	if _n == 0:
		return Vector2.ZERO
	var travelled := 0.0
	var i := _head - 1
	if i < 0:
		i += Tuning.TRAIL_SAMPLES
	var px := _x[i]
	var pz := _z[i]
	for step in range(1, _n):
		var j := i - step
		while j < 0:
			j += Tuning.TRAIL_SAMPLES
		var qx := _x[j]
		var qz := _z[j]
		var d := Vector2(qx - px, qz - pz).length()
		if travelled + d >= back:
			var t := 0.0 if d <= 0.0 else (back - travelled) / d
			return Vector2(lerpf(px, qx, t), lerpf(pz, qz, t))
		travelled += d
		px = qx
		pz = qz
	return Vector2(px, pz)


## Fill `out` with a position per candle, front first. Returns how many.
##
## ONE backward walk for the whole batch, not one per candle. The candles are at
## monotonically increasing distances back, so a single pass down the recorded
## path can emit each of them as it crosses that candle's threshold.
##
## Calling `sample_back` in a loop is the obvious way to write this and it is
## quadratic: thirty candles each walking ninety samples is 2,700 steps a frame,
## which is invisible in a game running one level and ruinous in a test suite
## running twenty of them - the pure tests went from about a second to over five
## minutes, which reads as a hang rather than as slow code.
func layout(count: int, out: Array[Vector2]) -> int:
	var n := mini(count, Tuning.MAX_CANDLES)
	out.resize(n)
	if _n == 0:
		for i in n:
			out[i] = Vector2.ZERO
		return n

	var i := _head - 1
	if i < 0:
		i += Tuning.TRAIL_SAMPLES
	var px := _x[i]
	var pz := _z[i]
	var travelled := 0.0
	var next := 0
	while next < n and back_for(next) <= 0.0:
		out[next] = Vector2(px, pz)
		next += 1

	for step in range(1, _n):
		if next >= n:
			break
		var j := i - step
		while j < 0:
			j += Tuning.TRAIL_SAMPLES
		var qx := _x[j]
		var qz := _z[j]
		var d := Vector2(qx - px, qz - pz).length()
		while next < n and travelled + d >= back_for(next):
			var t := 0.0 if d <= 0.0 else (back_for(next) - travelled) / d
			out[next] = Vector2(lerpf(px, qx, t), lerpf(pz, qz, t))
			next += 1
		travelled += d
		px = qx
		pz = qz

	# Anything further back than the trail remembers holds the oldest point.
	while next < n:
		out[next] = Vector2(px, pz)
		next += 1
	return n
