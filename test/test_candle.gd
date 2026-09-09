extends RefCounted

## One candle's recipe, and the arithmetic on top of it.
##
## These are intent tests: each states something the game is supposed to be
## ABOUT and would still pass if every constant moved.


func test_a_candle_starts_plain_and_cream(t: TestHarness) -> void:
	var c := Candle.make()
	t.eq(c.layers.size(), 1, "one layer to start with")
	t.eq(c.top_wax(), Wax.CREAM, "and it is the core colour")
	t.eq(c.glitter, 0, "nothing on it")
	t.eq(c.mould, 0, "and nothing done to it")


func test_every_candle_has_its_own_recipe(t: TestHarness) -> void:
	## The single most important fact in the game, and it was wrong for two
	## builds of the sibling version: a shared recipe deletes the whole skill,
	## because then the player's line decides nothing.
	var a := Candle.make()
	var b := Candle.make()
	a.dip(Wax.AQUA)
	t.eq(a.layers.size(), 2, "the one that was dipped gained a layer")
	t.eq(b.layers.size(), 1, "the one that was not, did not")


func test_a_pool_refuses_a_colour_already_on_top(t: TestHarness) -> void:
	## Which is why no level offers CREAM at a pool: it is the candle's own core,
	## so a cream pool would be a station with a gantry and a sign that does
	## nothing, and it reads on screen only as a batch that stays beige.
	var c := Candle.make()
	t.ok(not c.dip(Wax.CREAM), "cream on cream does nothing")
	t.ok(c.dip(Wax.AQUA), "a different colour takes")
	t.ok(not c.dip(Wax.AQUA), "the same one again does not")


func test_dipping_stops_at_the_ceiling(t: TestHarness) -> void:
	var c := Candle.make()
	var waxes := [Wax.AQUA, Wax.BUBBLEGUM, Wax.SUNBEAM, Wax.MINT, Wax.LILAC]
	for i in 40:
		c.dip(waxes[i % waxes.size()])
	t.ok(c.layers.size() <= Tuning.MAX_LAYERS, "never past MAX_LAYERS")


func test_contrast_counts_lightness_as_well_as_hue(t: TestHarness) -> void:
	## Hue distance ALONE is wrong, and this test caught it before it was ever
	## drawn: cream and bubblegum are near neighbours on the wheel and obviously
	## two colours, because one of them is nearly white.
	t.ok(Wax.reads_as_two(Wax.CREAM, Wax.BUBBLEGUM),
		"cream against bubblegum must read as two colours")
	t.ok(Wax.reads_as_two(Wax.AQUA, Wax.BUBBLEGUM),
		"and so must two colours far apart in hue")


func test_more_colours_is_worth_more_than_more_of_one(t: TestHarness) -> void:
	## The claim the whole wax system rests on: weaving two pools beats driving
	## through one twice. If this inverts, the pools stop being a decision.
	var one := Candle.make()
	one.dip(Wax.AQUA)
	var two := Candle.make()
	two.dip(Wax.AQUA)
	two.dip(Wax.BUBBLEGUM)
	t.gt(two.value(), one.value() * 1.15,
		"a second, contrasting colour must be worth having")


func test_the_silhouette_follows_the_recipe(t: TestHarness) -> void:
	## Radius, length and value are all functions of the same object, so the
	## candles on screen cannot disagree with the candles being paid for.
	var c := Candle.make()
	var r0 := c.radius()
	var l0 := c.length()
	c.dip(Wax.AQUA)
	t.gt(c.radius(), r0, "a dip makes it fatter")
	t.gt(c.length(), l0, "and longer")
	t.eq(c.radii().size(), c.layers.size(), "one radius per band")
	t.eq(c.band_offsets().size(), c.layers.size(), "and one offset per band")


func test_craft_multiplies_rather_than_adds(t: TestHarness) -> void:
	var plain := Candle.make()
	plain.dip(Wax.AQUA)
	var fancy := Candle.make()
	fancy.dip(Wax.AQUA)
	fancy.add_glitter(1)
	fancy.press(Wax.MOULDS.size() - 1)
	fancy.wrap_in(Wax.WRAPS.size() - 1)
	t.gt(fancy.value(), plain.value() * 2.0,
		"glitter, a mould and a wrapping together must more than double it")


func test_a_press_and_a_wrap_never_go_backwards(t: TestHarness) -> void:
	var c := Candle.make()
	t.ok(c.press(2), "a better mould takes")
	t.ok(not c.press(1), "a worse one does not")
	t.eq(c.mould, 2, "and does not downgrade it")
	t.ok(c.wrap_in(2), "same for wrapping")
	t.ok(not c.wrap_in(1), "and the same refusal")


func test_a_clone_is_independent(t: TestHarness) -> void:
	var a := Candle.make()
	a.dip(Wax.AQUA)
	var b := a.clone()
	b.dip(Wax.BUBBLEGUM)
	t.eq(a.layers.size(), 2, "the original is untouched")
	t.eq(b.layers.size(), 3, "the clone moved on")
