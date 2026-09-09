class_name Tuning
extends RefCounted

## Every number that shapes how Candle Gift feels, in one place, plus the
## arithmetic derived from it.
##
## Pure: nothing here reads live state. That is what lets `test/` check the
## shape of the curves - which is what a balance change accidentally breaks -
## without booting a game.
##
## `REFERENCE.md` is the observed record of the game this is modelled on. Where
## a number here has a shape rather than a value - the batch starting at one,
## the pools being half-width, the level being two sections - that file says
## why, with the timestamp in the walkthrough video it was read from.

# --- the track ------------------------------------------------------------
const LANE_HALF_WIDTH := 3.0   ## how far from centre a thumb may steer
const ROAD_HALF_WIDTH := 4.2   ## the road mesh is wider than the steerable band
const FORWARD_SPEED := 11.5    ## metres per second
const STEER_RATE := 11.0       ## exponential smoothing toward the target lane
const CHUNK := 12.0            ## metres between spawn decisions
const CHUNKS_PER_LEVEL := 34

## THE SECTION BOUNDARY. Before this chunk the candles lie flat and the runway
## is wax; at it they stand up; after it the machines that need a standing
## candle. The wall spans the whole track, so it is crossed exactly once and
## cannot be dodged - which is the difference between a section boundary and a
## power-up. See REFERENCE.md: flat at 15.5s in the walkthrough, standing at
## 15.8s, with the plate still visible behind the batch at 16.1s.
const ROTATE_CHUNK := 17

# --- the batch ------------------------------------------------------------
## ONE. A batch is something built over a run and over a campaign, not
## something handed out. At eight the first thirty seconds were free: nothing
## picked up mattered and losing three was an inconvenience. At one, the first
## loose candle on the runway is the most valuable thing in the game.
const START_CANDLES := 1
const MAX_CANDLES := 30
const TRAIL_GAP := 0.62        ## how far apart candles sit ALONG the path
const TRAIL_SAMPLES := 4000

# --- one candle -----------------------------------------------------------
const CORE_RADIUS := 0.30
const RADIUS_PER_LAYER := 0.045
const CANDLE_LENGTH := 1.9     ## across the lane lying down; its height standing
const BAND_HEIGHT := 0.10
const WICK_HEIGHT := 0.30
const MAX_LAYERS := 8
const MAX_GLITTER := 3

# --- what a candle is worth ----------------------------------------------
const BASE_VALUE := 9.0
const LAYER_VALUE := 0.34
const CONTRAST_VALUE := 0.30   ## for each adjacent pair that reads as two colours
const GLITTER_VALUE := 0.26
const SCENT_VALUE := 0.55

# --- the stations ---------------------------------------------------------
## A pool has to be longer than the batch is deep, or it cannot get the whole
## batch in even standing still - and short enough that one line misses the
## other pool. Half-width, in pairs, is what makes weaving a decision.
const POOL_LENGTH := 11.0
const POOL_INSET := 0.15

# --- pickups --------------------------------------------------------------
## Small on purpose. Money used to be most of what a run was worth, which made
## the batch - the thing the whole game is about building - a rounding error
## next to driving over green tags.
const CASH_VALUE := 45
const MAGNET_RADIUS := 2.0

## How plentiful loose candles are, and it RISES WITH THE LEVEL. Thirty candles
## is somewhere to get to, not somewhere to start: level one puts about a dozen
## on the whole runway, level six about thirty.
const LOOSE_BASE := 0.45
const LOOSE_PER_LEVEL := 0.06
const LOOSE_MAX := 0.85

# --- the obstacles --------------------------------------------------------
## Three kinds, because the reference has three: a coral hazard wall, a spiked
## axle reaching in from a post at the track edge, and a salmon bar that slides
## diagonally across. Flat costs rather than proportional ones, so a player can
## look at one and know what it costs.
const BARRIER_TAKE := 3
const ROLLER_TAKE := 3
const SWEEPER_TAKE := 3

## Sparse early and rising hard with the level.
##
## Measured before this was split out: at a flat 0.40/0.30/0.28 every policy
## ended level one with ONE OR TWO candles, having collected eight and lost
## eight. A batch that cannot outgrow the runway is not scarce, it is a
## treadmill - the player collects all game and finishes with what they started.
## Growth has to beat attrition while the batch is small, and stop doing so
## once it is big.
const BARRIER_CHANCE := 0.24
const ROLLER_CHANCE := 0.18
const SWEEPER_CHANCE := 0.16
const HAZARD_PER_LEVEL := 0.16
const CASH_CHANCE := 0.50
const GUARDED_CASH := 0.55

const COLLIDE_TOLERANCE := 0.34

# --- the end of a run -----------------------------------------------------
## `PAR` is the value the star rating is drawn from, and the end-of-run ruler
## uses your own best rather than a target. MEASURED, not chosen, with the
## policies in `test/policies.gd` over six levels - see NOTES.md for the table
## and re-measure whenever a station, a multiplier, the obstacle mix or the
## starting batch changes.
const PAR := 10000.0
const STAR_AT := [0.30, 0.60, 1.15]

const LEVEL_SCALE := 1.55      ## what a candle is worth, per level
const PRICE_SCALE := 1.70      ## what things cost, per level


static func scale_for(level: int) -> float:
	return pow(LEVEL_SCALE, level - 1)


static func price_for(level: int) -> float:
	return pow(PRICE_SCALE, level - 1)


static func level_seconds(_level: int) -> float:
	return (CHUNK * CHUNKS_PER_LEVEL) / FORWARD_SPEED


## How likely a chunk is to carry loose candles at this level.
static func loose_chance_for(level: int) -> float:
	return minf(LOOSE_MAX, LOOSE_BASE + float(level - 1) * LOOSE_PER_LEVEL)


## Never take more than half of what is there, and never less than one.
##
## With a batch that starts at ONE, a barrier worth three candles is not an
## obstacle, it is the end of the run before the player has touched anything.
## The cap keeps an early hit painful and survivable and leaves a late hit at
## its full flat cost, which is the number the player learns to read.
static func cap_take(take: int, count: int) -> int:
	return maxi(1, mini(take, maxi(1, count / 2)))


## Where a hazard, a banknote or a pickup goes across the runway. Everything the
## player must reach or dodge lives inside the band a thumb can steer across,
## which is LANE_HALF_WIDTH, not the width of the road mesh.
static func lane_x(unit: float, inset: float = 0.0) -> float:
	return clampf((unit - 0.5) * 2.0 * LANE_HALF_WIDTH,
		-LANE_HALF_WIDTH + inset, LANE_HALF_WIDTH - inset)


## How many stars a finished batch earns. Kept although nothing shows it to the
## player - the end-of-run screen asks "did you beat your best" instead -
## because the balance probe uses it to check the policies still separate.
static func stars_for(value: float, expected: float) -> int:
	if expected <= 0.0:
		return 0
	var r := value / expected
	var n := 0
	for t in STAR_AT:
		if r >= t:
			n += 1
	return n
