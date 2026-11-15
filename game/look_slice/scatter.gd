extends Node3D
## Seeded desert scatter (decision landforms): placement by slope and height
## read from the generated heights, one MultiMesh per mesh kind, densities
## scaled by the quality profile. Saguaro, ocotillo and prickly pear are
## modelled here procedurally (no CC0 scans of them exist on Poly Haven);
## boulders and shrubs are CC0 scans from Poly Haven.

const SEED := 20261115
const N := 1025
const HALF := 512.0
const PH := "res://assets/polyhaven/"
## The dressed patch (about 50 m across) at the centre gets full density.
const PATCH_RADIUS := 30.0

var _h: PackedFloat32Array
var _rng := RandomNumberGenerator.new()


func build(_owner: Node3D) -> void:
	_rng.seed = SEED
	_h = FileAccess.get_file_as_bytes("res://look_slice/generated/heights_roam.f32").to_float32_array()
	var density := 1.0
	if has_node("/root/Game") and Game.quality:
		density = Game.quality.scatter_density
	_place("Saguaro", _saguaro_meshes(), int(1800 * density), 0.0, 22.0, 0.15, 500.0, true)
	_place("Ocotillo", [_ocotillo_mesh()], int(1400 * density), 4.0, 30.0, 0.2, 300.0, false)
	_place("PricklyPear", [_prickly_pear_mesh()], int(5000 * density), 0.0, 25.0, 0.3, 160.0, false)
	for id in ["namaqualand_boulder_02", "namaqualand_boulder_03", "namaqualand_boulder_04", "namaqualand_boulder_05"]:
		_place_scan(id, int(350 * density), 8.0, 60.0, 0.6, 1.8, 250.0, 0.25)
	_place_scan("namaqualand_rocks_01", int(2500 * density), 0.0, 60.0, 0.6, 1.4, 70.0, 0.1)
	_place_scan("namaqualand_stones_01", int(4000 * density), 0.0, 45.0, 0.8, 1.4, 35.0, 0.03)
	_place_scan("wild_rooibos_bush", int(5000 * density), 0.0, 30.0, 0.7, 1.5, 120.0, 0.0)
	_place_scan("shrub_02", int(2500 * density), 0.0, 25.0, 0.5, 1.0, 100.0, 0.0)


func _hgt(x: float, z: float) -> float:
	var fx := clampf(x + HALF, 0.0, N - 1.001)
	var fz := clampf(z + HALF, 0.0, N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := _h[iz * N + ix]
	var b := _h[iz * N + ix + 1]
	var c := _h[(iz + 1) * N + ix]
	var d := _h[(iz + 1) * N + ix + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func _slope(x: float, z: float) -> float:
	var dx := _hgt(x + 1, z) - _hgt(x - 1, z)
	var dz := _hgt(x, z + 1) - _hgt(x, z - 1)
	return rad_to_deg(atan(Vector2(dx, dz).length() / 2.0))


## A position biased toward the dressed patch at the centre.
func _pick() -> Vector2:
	if _rng.randf() < 0.25:
		return Vector2(_rng.randfn(0, PATCH_RADIUS), _rng.randfn(0, PATCH_RADIUS))
	return Vector2(_rng.randf_range(-HALF + 2, HALF - 2), _rng.randf_range(-HALF + 2, HALF - 2))


func _place(node_name: String, meshes: Array, count: int, min_slope: float, max_slope: float,
		sink: float, vis_range: float, upright: bool) -> void:
	var per: Array = []
	for m in meshes:
		per.append([])
	var tries := 0
	var placed := 0
	while placed < count and tries < count * 6:
		tries += 1
		var p := _pick()
		var s := _slope(p.x, p.y)
		if s < min_slope or s > max_slope:
			continue
		var k := _rng.randi_range(0, meshes.size() - 1)
		var scale := _rng.randf_range(0.75, 1.25)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * scale)
		if not upright:
			b = Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0, 0.15)) * b
		per[k].append(Transform3D(b, Vector3(p.x, _hgt(p.x, p.y) - sink, p.y)))
		placed += 1
	for i in meshes.size():
		_multimesh("%s_%d" % [node_name, i], meshes[i], per[i], vis_range)


func _place_scan(id: String, count: int, min_slope: float, max_slope: float, smin: float, smax: float,
		vis_range: float, sink: float) -> void:
	var path := PH + "%s/%s_2k.gltf" % [id, id]
	if not ResourceLoader.exists(path):
		push_warning("look-slice: scan %s not imported" % path)
		return
	var scene: Node = load(path).instantiate()
	var mi := _first_mesh(scene)
	if mi == null:
		scene.free()
		return
	var mesh: Mesh = mi.mesh
	var xs: Array = []
	var tries := 0
	while xs.size() < count and tries < count * 6:
		tries += 1
		var p := _pick()
		var s := _slope(p.x, p.y)
		if s < min_slope or s > max_slope:
			continue
		var sc := _rng.randf_range(smin, smax)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * sc)
		xs.append(Transform3D(b, Vector3(p.x, _hgt(p.x, p.y) - sink * sc, p.y)))
	scene.free()
	_multimesh(id, mesh, xs, vis_range)


func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _first_mesh(c)
		if m:
			return m
	return null


## One MultiMesh per 64 m cell, so the renderer picks each cell's level of
## detail and visibility from its own distance (decision renderer). A single
## MultiMesh spanning the whole square would always draw at full detail.
const CELL := 64.0


func _multimesh(node_name: String, mesh: Mesh, xs: Array, vis_range: float) -> void:
	if xs.is_empty():
		return
	var cells := {}
	for x in xs:
		var key := Vector2i(floori(x.origin.x / CELL), floori(x.origin.z / CELL))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(x)
	var group := Node3D.new()
	group.name = node_name
	add_child(group)
	for key in cells:
		var list: Array = cells[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%d_%d" % [key.x, key.y]
		mmi.multimesh = mm
		mmi.visibility_range_end = vis_range
		mmi.visibility_range_end_margin = vis_range * 0.1
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		group.add_child(mmi)


# --- procedural Sonoran plants ---------------------------------------------------

func _cactus_material(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.75
	m.rim_enabled = true
	m.rim = 0.15
	return m


## A ribbed column from p0 to p1 with radius r; ribs as a radial ripple.
func _ribbed(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, ribs := 12, seg := 16, rings := 10) -> void:
	var axis := (p1 - p0)
	var up := axis.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := up.cross(side)
	var verts: Array = []
	for j in rings + 1:
		var t := float(j) / rings
		var c := p0 + axis * t
		var r := lerpf(r0, r1, t)
		if j == rings:
			r *= 0.55  # rounded crown
		var row: Array = []
		for i in seg * 2:
			var a := TAU * i / (seg * 2)
			var rr := r * (1.0 + 0.09 * cos(a * ribs))
			var n := (side * cos(a) + fwd * sin(a))
			row.append([c + n * rr, n])
		verts.append(row)
	for j in rings:
		for i in seg * 2:
			var i2 := (i + 1) % (seg * 2)
			for v in [verts[j][i], verts[j + 1][i], verts[j][i2], verts[j][i2], verts[j + 1][i], verts[j + 1][i2]]:
				st.set_normal(v[1])
				st.add_vertex(v[0])


func _saguaro_meshes() -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	for variant in 4:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var hgt := rng.randf_range(4.5, 9.0)
		var r := rng.randf_range(0.22, 0.32)
		_ribbed(st, Vector3.ZERO, Vector3(0, hgt, 0), r, r * 0.92, 12)
		for arm in rng.randi_range(0, 3):
			var ang := rng.randf() * TAU
			var y := rng.randf_range(hgt * 0.35, hgt * 0.6)
			var dir := Vector3(cos(ang), 0, sin(ang))
			var elbow := Vector3(0, y, 0) + dir * rng.randf_range(0.6, 1.0) + Vector3(0, 0.25, 0)
			_ribbed(st, Vector3(0, y, 0) + dir * r * 0.5, elbow, r * 0.7, r * 0.65, 10, 12, 4)
			_ribbed(st, elbow - Vector3(0, 0.15, 0), elbow + Vector3(0, rng.randf_range(1.0, hgt - y - 0.5), 0), r * 0.68, r * 0.6, 10, 12, 8)
		st.set_material(_cactus_material(Color(0.33, 0.42, 0.27)))
		out.append(st.commit())
	return out


func _ocotillo_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	for s in 16:
		var ang := rng.randf() * TAU
		var lean := rng.randf_range(0.08, 0.35)
		var len := rng.randf_range(2.5, 5.0)
		var top := Vector3(cos(ang) * lean * len, len, sin(ang) * lean * len)
		_ribbed(st, Vector3(cos(ang) * 0.05, 0, sin(ang) * 0.05), top, 0.035, 0.012, 0, 6, 6)
	st.set_material(_cactus_material(Color(0.36, 0.32, 0.26)))
	return st.commit()


func _prickly_pear_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	var pads: Array = [[Vector3(0, 0.12, 0), 0.0]]
	for i in 9:
		var parent: Array = pads[rng.randi_range(0, pads.size() - 1)]
		var a := rng.randf() * TAU
		var tilt := rng.randf_range(-0.6, 0.6)
		var c: Vector3 = parent[0] + Vector3(cos(a) * 0.15, rng.randf_range(0.12, 0.22), sin(a) * 0.15)
		pads.append([c, a, tilt])
	for p in pads:
		_pad(st, p[0], float(p[1]), float(p[2]) if p.size() > 2 else 0.0)
	st.set_material(_cactus_material(Color(0.36, 0.45, 0.28)))
	return st.commit()


func _pad(st: SurfaceTool, c: Vector3, yaw: float, tilt: float) -> void:
	# A flattened ellipsoid: 0.28 m tall, 0.2 m wide, 0.04 m thick.
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, tilt)
	var rows := 8
	var cols := 12
	var pts: Array = []
	for j in rows + 1:
		var v := PI * j / rows
		var row: Array = []
		for i in cols:
			var u := TAU * i / cols
			var n := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
			var p := Vector3(n.x * 0.1, n.y * 0.14, n.z * 0.02)
			row.append([c + b * p, (b * Vector3(n.x / 0.1, n.y / 0.14, n.z / 0.02)).normalized()])
		pts.append(row)
	for j in rows:
		for i in cols:
			var i2 := (i + 1) % cols
			for v in [pts[j][i], pts[j + 1][i], pts[j][i2], pts[j][i2], pts[j + 1][i], pts[j + 1][i2]]:
				st.set_normal(v[1])
				st.add_vertex(v[0])
