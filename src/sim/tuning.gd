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
## HOW MUCH WIDER EACH COAT IS. Small on purpose.
##
## At 0.045 against a 0.30 core, eight coats doubled the candle's radius and the
## silhouette became a visibly stepped cone - on the phone it read as a stack of
## plates. A dip adds a skin, not a shelf: 0.012 is a rim you can see at the edge
## of each band and a silhouette that is still a candle.
const RADIUS_PER_LAYER := 0.012
const CANDLE_LENGTH := 1.9     ## across the lane lying down; its height standing
const BAND_HEIGHT := 0.10

## HOW MUCH SHORTER EACH SUCCESSIVE COAT IS, as a fraction of the candle.
##
## A dip covers the candle from the bottom UP TO a height, and each dip after it
## reaches a little less far - which is what happens when you dip a candle
## repeatedly and is why a layered candle has rings. At 0.085 the eighth and last
## coat still reaches 40% of the way up, so every layer the player put on is
## visible and none is buried.
const COAT_DROP := 0.085
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
## A banknote is worth 5, because the reference's price tags say `5 $`. Money
## in this game is in the reference's units - see VALUE_SCALE.
const CASH_VALUE := 5

## THE DENOMINATIONS, taken from the reference's own tags.
##
## `REFERENCE.md` records three values read off price tags lying on the track:
## `5 $`, `154 $`, `610 $`. Those are not three different levels of the same
## tag - a tag is a tag, and the reference shows them as distinct things - so
## money in this game comes in three denominations rather than one.
##
## The multipliers are `1 / 6 / 24` because that is what the observed values
## divide back to - but NOT all at the same level, and saying so was wrong the
## first time this comment was written. The three tags were read off different
## frames of a walkthrough that covers several levels:
##
## | tag | tier | level it reads at |
## |---|---|---|
## | `5 $` | 0 | 1 (`scale_for(1)` = 1.0, so 5 x 1 x 1) |
## | `154 $` | 1 | 10 (`scale_for(10)` = 5.16, so 5 x 6 x 5.16 = 155) |
## | `610 $` | 2 | 10 (5 x 24 x 5.16 = 619) |
##
## That is the honest reading: a `5 $` tag in early footage and bigger tags
## later. `test_the_denominations_are_the_reference_s_own_tags` asserts each
## against the level it was actually observed at, so the claim in this table is
## the thing being checked rather than a tidier one that happens to pass.
const CASH_TIERS := [1.0, 6.0, 24.0]

## WHICH TIER LIES WHERE, and this is the mechanic rather than the decoration.
##
## A loose tag on open road is always the small one. **Every large tag is behind
## a hazard**, which turns money from something you drive over into something you
## decide about - and it is the reference's own arrangement, which puts its
## banknote lines behind obstacles.
##
## So: this many of all cash chunks carry the middle tag and this many the big
## one, and a chunk that draws either PLANTS ITS OWN BARRIER on the cash line
## whatever the ordinary barrier roll says. The guard is part of the tag rather
## than a coincidence it depends on - see the comment in `Sim._spawn_chunk` for
## the two ways the coincidence version failed.
##
## MEASURED, not chosen. The first attempt made every guarded note tier 1 and a
## fifth of those tier 2, which put the mean multiplier at 5.9 and money at five
## times its old share: idling went from 0 stars to 2 (a policy that does nothing
## but drive forward was collecting a fortune), and weaving fell from 6.0x idling
## to 2.5x. `weaving the pools beats only collecting` caught it, which is what
## that guard is for. See NOTES.md for the table.
const TIER1_CHANCE := 0.14
const TIER2_CHANCE := 0.035
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
## FEWER NOTES, WORTH MORE EACH. Halved when the denominations arrived: the
## reference's tags are occasional things carrying a real number, not a stream
## of identical fives, and the total money a run is worth has to stay where it
## was or the batch stops being the point of the game.
const CASH_CHANCE := 0.26
const GUARDED_CASH := 0.55

const COLLIDE_TOLERANCE := 0.34

# --- the end of a run -----------------------------------------------------
## `PAR` is the value the star rating is drawn from, and the end-of-run ruler
## uses your own best rather than a target. MEASURED, not chosen, with the
## policies in `test/policies.gd` over six levels - see NOTES.md for the table
## and re-measure whenever a station, a multiplier, the obstacle mix or the
## starting batch changes.
## MONEY IS IN THE REFERENCE'S UNITS.
##
## A level-one run of the weaving bot used to appraise at 18,273 while the
## reference's own footage rewards about 540 for a comparable run - thirty-four
## times out. That is not a cosmetic difference: the only two shop prices ever
## observed are $1,000 and $4,000, and against 18,273 a run they are not prices
## at all. It also put "148K $" in a money pill that should read "540 $".
##
## One constant, applied once in `appraise`, so everything downstream - PAR, the
## ruler, the pill, the shop ladder - moves together and stays comparable.
const VALUE_SCALE := 0.03

## `PAR` is the value the star rating is drawn from, and the end-of-run ruler
## uses your own best rather than a target. MEASURED, not chosen - see NOTES.md
## for the table, and re-measure whenever a station, a multiplier, the obstacle
## mix or the value of anything changes.
const PAR := 450.0
const STAR_AT := [0.30, 0.60, 1.15]

## WHAT A CANDLE IS WORTH, PER LEVEL - and it was hyperinflationary at 1.55.
##
## A run's value multiplied EIGHTY TIMES over ten levels, which makes any fixed
## price list meaningless: measured by playing the progression, all seven shops
## were bought by level nine, and by level fifteen a run paid nine hundred times
## the first shop's price. A ladder that finishes in nine levels is not a
## meta-game, it is a tutorial.
##
## 1.20 is 6.2x over ten levels and 38x over twenty - still a strong sense of
## getting richer, and slow enough that a price list can span the game.
##
## This does not touch any recorded number: `norm` divides by `scale_for(level)`
## and the golden is level one, where the scale is 1.0 either way.
const LEVEL_SCALE := 1.20
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
