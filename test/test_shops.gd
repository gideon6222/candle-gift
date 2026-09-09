extends RefCounted

## The shop ladder.


func test_the_ladder_is_ordered_and_unique(t: TestHarness) -> void:
	var seen := {}
	var last := 0.0
	for s in Shops.ALL:
		t.ok(not seen.has(s.id), "two shops share the id '%s'" % s.id)
		seen[s.id] = true
		t.gt(float(s.price), last, "shop '%s' is not dearer than the one before it" % s.id)
		last = float(s.price)
		t.ok(String(s.name) != "", "shop '%s' has no name" % s.id)
		t.ok(String(s.blurb) != "", "shop '%s' has no blurb, so its card says nothing" % s.id)


## The two prices that were actually observed in the reference. Everything else
## in the ladder is ours and may be tuned; these two are a record of the game
## being copied and should only move deliberately.
func test_the_observed_prices_are_the_observed_prices(t: TestHarness) -> void:
	t.approx(float(Shops.by_id(Shops.ONLINE).price), 1000.0, 0.01,
		"the ONLINE SHOP price no longer matches the reference")
	t.approx(float(Shops.by_id(Shops.SCENT).price), 4000.0, 0.01,
		"the SCENT SHOP price no longer matches the reference")


## Every rung has to actually change something, or it is a price with nothing
## behind it.
func test_every_shop_grants_something_reachable(t: TestHarness) -> void:
	var owned: Array = []
	var before := Shops.stats_for(owned)
	for s in Shops.ALL:
		owned.append(String(s.id))
		var after := Shops.stats_for(owned)
		t.ok(after != before, "buying '%s' changed nothing at all" % s.id)
		before = after

	## And the top of the ladder must reach the top of the content. A press
	## level that never reaches the last mould means a die nobody can ever be
	## stamped with.
	var all_stats := Shops.stats_for(owned)
	t.eq(int(all_stats.press_level), Wax.MOULDS.size() - 2,
		"owning every shop does not unlock the last mould")
	t.eq(int(all_stats.wrap_level), Wax.WRAPS.size() - 2,
		"owning every shop does not unlock the last wrap")
	t.eq(all_stats.has_scent, true, "owning every shop does not open the scent station")


## DERIVED, NOT STORED. The stats are a function of what is owned, so a shop
## inserted into the middle of the ladder later cannot leave an old save with a
## number that no longer matches its own list.
func test_stats_are_a_function_of_what_is_owned(t: TestHarness) -> void:
	t.eq(int(Shops.stats_for([]).earn_level), 0, "a fresh player has an earn level")
	t.eq(Shops.stats_for([]).has_scent, false, "a fresh player already has scent")
	var mid := Shops.stats_for([Shops.ONLINE, Shops.BOUTIQUE, Shops.SCENT])
	t.eq(int(mid.earn_level), 1, "the online shop did not raise the earn level")
	t.eq(int(mid.press_level), 1, "the boutique did not raise the press level")
	t.eq(mid.has_scent, true, "the scent shop did not open the scent station")
	t.eq(int(mid.wrap_level), 0, "a shop that is not owned granted its wrap anyway")

	## Owning a later rung as well as an earlier one lands on the higher value
	## rather than adding them together.
	var both := Shops.stats_for([Shops.ONLINE, Shops.DEPARTMENT])
	t.eq(int(both.earn_level), 2, "two shops on the same field did not take the higher")


## THE LADDER, and it is the reason `can_buy` exists at all.
##
## Without it one lucky run could buy the FLAGSHIP STORE outright and skip every
## shop under it - the player would own the best wrap in the game while the press
## was still stamping PLAIN, and the whole middle of the progression would never
## be seen.
func test_a_shop_cannot_be_bought_out_of_order(t: TestHarness) -> void:
	t.eq(Shops.can_buy([], 1e9, Shops.FLAGSHIP), false,
		"the last shop was buyable first, with enough money")
	t.eq(Shops.can_buy([], 1e9, Shops.ONLINE), true,
		"the first shop was not buyable with plenty of money")
	t.eq(Shops.can_buy([Shops.ONLINE], 1e9, Shops.ONLINE), false,
		"a shop already owned was buyable again")
	t.eq(Shops.can_buy([Shops.ONLINE], 1e9, Shops.BOUTIQUE), true,
		"the second rung was not buyable once the first was owned")


func test_a_shop_cannot_be_bought_without_the_money(t: TestHarness) -> void:
	var price := float(Shops.by_id(Shops.ONLINE).price)
	t.eq(Shops.can_buy([], price - 0.01, Shops.ONLINE), false,
		"a shop was buyable a penny short")
	t.eq(Shops.can_buy([], price, Shops.ONLINE), true,
		"a shop was not buyable with exactly its price")


func test_the_ladder_ends(t: TestHarness) -> void:
	var owned := []
	for s in Shops.ALL:
		owned.append(String(s.id))
	t.eq(Shops.next_for(owned).is_empty(), true,
		"owning everything still offers something to buy")
	t.eq(Shops.can_buy(owned, 1e9, Shops.FLAGSHIP), false,
		"a shop was buyable after everything was owned")


func test_an_unknown_id_is_refused_rather_than_crashing(t: TestHarness) -> void:
	t.eq(Shops.by_id("not-a-shop").is_empty(), true, "an unknown id returned a shop")
	t.eq(Shops.can_buy([], 1e9, "not-a-shop"), false, "an unknown id was buyable")
	## A save from a future version, or a corrupt one, must not grant anything.
	var stats := Shops.stats_for(["not-a-shop", "also-not-a-shop"])
	t.eq(int(stats.earn_level), 0, "an unknown owned id granted an earn level")
	t.eq(stats.has_scent, false, "an unknown owned id opened the scent station")
