extends SceneTree

var _main
var _seconds := 5.0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		_seconds = float(a)
	var scene: PackedScene = load("res://src/game/main.tscn")
	_main = scene.instantiate()
	root.add_child(_main)
	_main.freeze()
	var mem := {}
	var step := 1.0 / 60.0
	for i in int(round(_seconds / step)):
		Policies.steer(Policies.WEAVE, _main.sim, mem)
		_main.advance(step, step)
	var sim = _main.sim
	print("t=%.2f  distance=%.2f  cam_z=%.2f  count=%d" % [sim.time, sim.distance, _main._cam_z, sim.count()])
	print("cam eye=", _main._cam.transform.origin)
	for st in sim.stations:
		var sz := float(st.z)
		if sz < _main._cam_z - 20.0 or sz > sim.distance + 60.0:
			continue
		print("  station z=%7.2f  d_from_cam=%7.2f  d_from_player=%7.2f  L=%s R=%s" % [
			sz, sz - _main._cam_z, sz - sim.distance,
			Stations.KINDS[int(st.left.kind)].label, Stations.KINDS[int(st.right.kind)].label])
	for r in _main._rigs:
		if not r.visible:
			continue
		for h in r.get_meta("halves"):
			var liq: MeshInstance3D = h.liquid
			var q: PlaneMesh = liq.mesh
			var gt := liq.global_transform.origin
			print("   pool x=%6.2f y=%5.3f z=%7.2f  size=%s  vis=%s  scale=%s" % [
				gt.x, gt.y, gt.z, q.size, liq.visible, liq.scale])
			print("   world span x: %.2f .. %.2f   (road +-%.2f)" % [
				gt.x - q.size.x * 0.5, gt.x + q.size.x * 0.5, Tuning.ROAD_HALF_WIDTH])
		break

	var named := {
		"wicks": _main._wicks, "ribbons": _main._ribbons, "bows": _main._bows,
		"sparks": _main._sparks, "stripes": _main._stripes, "loose": _main._loose,
		"loose_tips": _main._loose_tips, "notes": _main._notes,
		"note_holes": _main._note_holes, "barriers": _main._barriers,
		"spikes": _main._spikes, "bar_marks": _main._bar_marks,
		"sweepers": _main._sweepers, "sweep_tips": _main._sweep_tips,
		"towers": _main._towers, "tower_tips": _main._tower_tips,
		"posts": _main._posts,
	}
	for bi in _main._bands.size():
		named["bands_%d" % bi] = _main._bands[bi]
	for k in named:
		var mmi: MultiMeshInstance3D = named[k]
		var mm: MultiMesh = mmi.multimesh
		var near := []
		for n in mm.visible_instance_count:
			var tr := mm.get_instance_transform(n)
			var o := tr.origin
			if o.z > _main._cam_z - 4.0 and o.z < _main._cam_z + 22.0:
				near.append("z=%.1f x=%.1f y=%.1f sx=%.2f sy=%.2f sz=%.2f" % [
					o.z, o.x, o.y, tr.basis.get_scale().x, tr.basis.get_scale().y,
					tr.basis.get_scale().z])
		if near.size() > 0:
			print("  %-12s count=%d  near=%d" % [k, mm.visible_instance_count, near.size()])
			for t2 in near.slice(0, 4):
				print("       ", t2)

	var vis := 0
	for r in _main._rigs:
		if r.visible:
			vis += 1
			print("  RIG visible at z=%.2f" % r.position.z)
	print("visible rigs: %d" % vis)
	quit(0)
