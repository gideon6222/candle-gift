extends RefCounted

## THE VERSION IS ONE FACT IN THREE PLACES AND NO CODE DERIVES IT.
##
## `Changelog.VERSION` is what the pause panel shows. `version/name` in
## `export_presets.cfg` is what Android's app info shows - and there are TWO
## copies of it, one for the debug APK preset and one for the Play AAB preset,
## because Godot will not read a constant out of a script at export time.
##
## The failure this produces is quiet and lands exactly where it hurts: the game
## says one version, the phone says another, and "did my build land" - the
## question the build stamp and the changelog exist to answer - gets two
## different answers depending on where you look. The AAB copy is the worse of
## the two, because it is the one nobody sees until a store upload.
##
## Pure, so it runs in CI with no GPU. Reading a config file is not a scene.


func test_the_version_agrees_everywhere(t: TestHarness) -> void:
	var cfg := FileAccess.get_file_as_string("res://export_presets.cfg")
	t.gt(float(cfg.length()), 0.0, "export_presets.cfg is missing or empty")

	var found := 0
	for line in cfg.split("\n"):
		var s := line.strip_edges()
		if not s.begins_with("version/name="):
			continue
		found += 1
		var value := s.substr("version/name=".length()).strip_edges().trim_prefix('"').trim_suffix('"')
		t.eq(value, Changelog.VERSION,
			"an export preset says version %s but Changelog.VERSION is %s"
				% [value, Changelog.VERSION])

	## BOTH presets, asserted by count. Checking "every version/name agrees"
	## passes vacuously if the presets file loses the key entirely, which is the
	## shape of a construct that cannot fail.
	t.eq(found, 2,
		"expected a version/name in both the APK and the AAB preset, found %d" % found)


## AND THE CODE, which is the number the store actually reads.
##
## The test above collected only `version/name=` lines, so `version/code` was
## asserted nowhere in this repo and sat at 1 while the name climbed. Play
## rejects every upload after the first unless the code is higher than the last
## one, and nothing here would have caught that until the rejection.
##
## The code is tied to the changelog rather than derived at runtime: one released
## entry is one upload, so it rises exactly when a note is written for it and can
## never go backwards or stand still.
func test_the_version_code_agrees_and_counts_the_releases(t: TestHarness) -> void:
	var cfg := FileAccess.get_file_as_string("res://export_presets.cfg")
	t.gt(float(cfg.length()), 0.0, "export_presets.cfg is missing or empty")

	var codes: Array[int] = []
	for line in cfg.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("version/code="):
			codes.append(int(s.substr("version/code=".length()).strip_edges()))

	## Both presets, asserted by count, for the same reason the names are.
	t.eq(codes.size(), 2,
		"expected a version/code in both the APK and the AAB preset, found %d" % codes.size())

	for i in codes.size():
		t.eq(codes[i], codes[0],
			"export preset %d says version/code %d but preset 0 says %d" % [i, codes[i], codes[0]])
		t.eq(codes[i], Changelog.RELEASES.size(),
			"version/code is %d but the changelog carries %d releases - bump the code to %d"
				% [codes[i], Changelog.RELEASES.size(), Changelog.RELEASES.size()])


func test_the_top_release_is_the_current_version(t: TestHarness) -> void:
	## A bumped constant with no entry under it is a build whose changes the
	## player cannot read - and the changelog is the only place they are told
	## what is different.
	t.gt(float(Changelog.RELEASES.size()), 0.0, "the changelog has no releases in it")
	t.eq(Changelog.RELEASES[0]["version"], Changelog.VERSION,
		"the newest changelog entry is %s but the build is %s"
			% [Changelog.RELEASES[0]["version"], Changelog.VERSION])


func test_every_release_says_what_changed(t: TestHarness) -> void:
	## Entries are for the player, so an empty one is worse than none: it
	## promises a note and delivers a heading.
	for r in Changelog.RELEASES:
		t.gt(float(String(r["version"]).length()), 0.0, "a release has no version")
		t.gt(float(r["notes"].size()), 0.0,
			"release %s has no notes under it" % r["version"])
