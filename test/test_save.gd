extends RefCounted

## The save file, and every way it can be wrong.


func test_a_fresh_install_gets_every_default(t: TestHarness) -> void:
	Save._reset_latch_for_tests()
	Save.wipe()
	Save._reset_latch_for_tests()
	var s := Save.load_state()
	for k in Save.DEFAULTS:
		t.ok(s.has(k), "a fresh save is missing '%s'" % k)
		t.eq(s[k], Save.DEFAULTS[k], "a fresh save has the wrong '%s'" % k)


func test_a_round_trip_keeps_every_field(t: TestHarness) -> void:
	Save._reset_latch_for_tests()
	Save.store({
		"cash": 1234.5, "level": 7, "best": 9000.0,
		"earn_level": 2, "press_level": 1, "wrap_level": 3, "has_scent": true,
	})
	var s := Save.load_state()
	t.approx(s.cash, 1234.5, 0.001, "cash did not survive a round trip")
	t.eq(s.level, 7, "level did not survive a round trip")
	t.approx(s.best, 9000.0, 0.001, "best did not survive a round trip")
	t.eq(s.earn_level, 2, "earn_level did not survive a round trip")
	t.eq(s.has_scent, true, "has_scent did not survive a round trip")


## JSON HAS ONE NUMBER TYPE.
##
## Every int written comes back as a float, so `level` loads as 3.0 - which is
## truthy, prints as "3", compares equal to 3, and then indexes an array as a
## float somewhere completely unrelated. The loader coerces to the type of the
## default, and this is the test that says so.
func test_ints_come_back_as_ints(t: TestHarness) -> void:
	Save._reset_latch_for_tests()
	Save.store({"level": 5, "earn_level": 2})
	var s := Save.load_state()
	t.eq(typeof(s.level), TYPE_INT, "level came back as something other than an int")
	t.eq(typeof(s.earn_level), TYPE_INT, "earn_level came back as something other than an int")
	t.eq(typeof(s.cash), TYPE_FLOAT, "cash came back as something other than a float")


func test_a_corrupt_file_reads_as_a_fresh_install(t: TestHarness) -> void:
	Save._reset_latch_for_tests()
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string("{this is not json")
	f = null
	var s := Save.load_state()
	t.eq(s.level, 1, "a corrupt save did not fall back to a fresh install")
	t.eq(s.cash, 0.0, "a corrupt save did not fall back to a fresh install")


## A save written before a field existed must not read as that field being off.
func test_a_missing_key_reads_as_its_default_not_as_null(t: TestHarness) -> void:
	Save._reset_latch_for_tests()
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string('{"cash": 50.0}')
	f = null
	var s := Save.load_state()
	t.eq(s.level, 1, "a save missing 'level' did not default it")
	t.eq(s.has_scent, false, "a save missing 'has_scent' did not default it")
	t.approx(s.cash, 50.0, 0.001, "the key that WAS present was lost")


func test_a_negative_or_zero_level_is_clamped(t: TestHarness) -> void:
	Save._reset_latch_for_tests()
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string('{"level": -4, "cash": -100.0}')
	f = null
	var s := Save.load_state()
	t.eq(s.level, 1, "a level of -4 was not clamped to 1")
	t.eq(s.cash, 0.0, "negative cash was not clamped to 0")


## THE LATCH, and it is the reason this file exists rather than two lines inline.
##
## The game saves when it loses focus. "Clear my progress" is followed within a
## frame by exactly that, so the erased state gets written straight back over
## the wipe and the button appears to do nothing. Verified by removing the latch
## and watching this fail.
func test_a_wipe_cannot_be_undone_by_a_later_save(t: TestHarness) -> void:
	Save._reset_latch_for_tests()
	Save.store({"cash": 4321.0, "level": 9})
	Save.wipe()
	Save.store({"cash": 4321.0, "level": 9})   # what visibilitychange does
	Save._reset_latch_for_tests()
	var s := Save.load_state()
	t.eq(s.level, 1, "a save after a wipe put the progress back")
	t.eq(s.cash, 0.0, "a save after a wipe put the money back")


## The owned list is the one field that is not a number, and it is the one a
## hand-edited or future-version file can put anything into.
func test_the_owned_list_is_rebuilt_rather_than_trusted(t: TestHarness) -> void:
	Save._reset_latch_for_tests()
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string('{"owned": ["online", 7, null, "online", "boutique"]}')
	f = null
	var s := Save.load_state()
	t.eq(s.owned, ["online", "boutique"],
		"the owned list kept a non-string id or a duplicate")


func test_owned_survives_a_round_trip(t: TestHarness) -> void:
	Save._reset_latch_for_tests()
	Save.store({"owned": [Shops.ONLINE, Shops.BOUTIQUE]})
	var s := Save.load_state()
	t.eq(s.owned.size(), 2, "the owned list did not survive a round trip")
	t.eq(Shops.owns(s.owned, Shops.BOUTIQUE), true, "a bought shop was lost")


## A save with a garbage owned list must not be able to grant anything.
func test_a_save_that_is_not_an_array_falls_back_to_owning_nothing(t: TestHarness) -> void:
	Save._reset_latch_for_tests()
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string('{"owned": "everything"}')
	f = null
	var s := Save.load_state()
	t.eq(s.owned, [], "a non-array owned field was not rejected")


## SETTINGS ARE A DIFFERENT FILE, and this is the assertion that keeps them so.
##
## The pause screen offers to erase your progress next to switches that control
## sound. Wiping the save must not silence the game, and turning the music off
## must not be able to touch a coin.
func test_settings_and_progress_do_not_share_a_file(t: TestHarness) -> void:
	t.ok(Settings.PATH != Save.PATH, "settings and progress share a file")
	Save._reset_latch_for_tests()
	Settings.wipe()
	Save.store({"cash": 999.0, "level": 3})
	Settings.store({"sound": false, "music_track": 0})

	var s := Save.load_state()
	t.approx(s.cash, 999.0, 0.01, "writing settings disturbed the save")
	t.eq(s.level, 3, "writing settings disturbed the save")

	## And erasing progress leaves the preferences alone.
	Save.wipe()
	var prefs := Settings.load_state()
	t.eq(prefs.sound, false, "wiping the save also reset the sound switch")
	t.eq(int(prefs.music_track), 0, "wiping the save also reset the music choice")
	Save._reset_latch_for_tests()


## A SWITCH DEFAULTS ON, and a file written before the switch existed must not
## read as it being off.
##
## The trap is testing truthiness instead of `== false`: a missing key and a key
## explicitly set to false look identical to `if not d.get(k)`, so everyone
## upgrading silently gets the switch turned off.
func test_a_settings_key_added_later_defaults_on(t: TestHarness) -> void:
	Settings.wipe()
	var f := FileAccess.open(Settings.PATH, FileAccess.WRITE)
	f.store_string('{"sound": false}')
	f = null
	var s := Settings.load_state()
	t.eq(s.sound, false, "an explicit false was not respected")
	t.eq(int(s.music_track), 1, "a key the file has never heard of read as its non-default")


func test_settings_survive_a_round_trip(t: TestHarness) -> void:
	Settings.wipe()
	Settings.store({"sound": false, "music_track": 3})
	var s := Settings.load_state()
	t.eq(s.sound, false, "sound did not survive a round trip")
	t.eq(int(s.music_track), 3, "the music choice did not survive a round trip")
