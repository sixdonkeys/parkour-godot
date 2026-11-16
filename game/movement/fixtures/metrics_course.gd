class_name MetricsCourse
extends Node3D
## Builds a course from a `metrics-course/1` file (docs/fixtures/metrics-course.json,
## written by tools/gen/metrics_course.py): gray blocks in stepped, known
## sizes. All static boxes share one StaticBody3D, so the seam between two
## blocks is an edge inside one body, which Jolt's internal-edge removal
## smooths over; separate bodies would leave seams a flat-bottomed body can
## catch on.

const TAG_COLORS := {
	"ground": Color(0.56, 0.56, 0.54), "pit-floor": Color(0.25, 0.25, 0.27), "outer-wall": Color(0.33, 0.34, 0.37),
	"ledge": Color(0.66, 0.62, 0.52), "step": Color(0.62, 0.66, 0.56), "stairs": Color(0.62, 0.66, 0.56),
	"ramp": Color(0.58, 0.63, 0.70), "wall": Color(0.47, 0.44, 0.42), "beam": Color(0.75, 0.6, 0.3),
	"deck": Color(0.75, 0.6, 0.3), "post": Color(0.4, 0.4, 0.4), "tower": Color(0.5, 0.48, 0.55),
	"mover": Color(0.85, 0.45, 0.15), "terrain": Color(0.6, 0.52, 0.4),
}

## Jolt rounds a box's edges by its margin. Ledges must be sharp for a
## landing to be judged at the edge, so the margin is kept tiny.
const EDGE_MARGIN := 0.002

var data: Dictionary = {}
var clock: WorldClock
var world: StaticBody3D
var movers: Dictionary = {}
## Draw the one-meter grid on the blocks. Its lines are edges the
## anti-aliasing pass has to work on (about a quarter of a millisecond of GPU
## at the Neo's resolution), so a frame-budget run can turn it off.
var grid := true
var _materials: Dictionary = {}
var _grid: ImageTexture


static func load_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("metrics course: cannot read %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or parsed.get("format", "") != "metrics-course/1":
		push_error("metrics course: %s is not a metrics-course/1 file" % path)
		return {}
	return parsed


func build(course: Dictionary) -> void:
	data = course
	clock = WorldClock.new()
	clock.name = "WorldClock"
	add_child(clock)
	world = StaticBody3D.new()
	world.name = "World"
	add_child(world)
	for p in course.get("pieces", []):
		match String(p.get("kind", "")):
			"box":
				_add_box(world, p)
			"heightfield":
				_add_heightfield(p)
			"mover":
				_add_mover(p)
			_:
				push_error("metrics course: unknown piece kind in %s" % p.get("id", "?"))


func spawn_point(id_or_pos) -> Dictionary:
	if id_or_pos is Array:
		return {"pos": _v3(id_or_pos), "yaw": 0.0}
	for s in data.get("spawns", []):
		if s["id"] == id_or_pos:
			return {"pos": spawn_position(s), "yaw": deg_to_rad(float(s.get("yaw_deg", 0.0)))}
	push_error("metrics course: no spawn named %s" % str(id_or_pos))
	return {"pos": Vector3.ZERO, "yaw": 0.0}


## Where a spawn is now. One tied to a moving surface rides with it: its
## `pos` is where it is at world tick 0.
func spawn_position(s: Dictionary) -> Vector3:
	var at := _v3(s["pos"])
	var m: MovingSurface = movers.get(String(s.get("on_mover", "")))
	if m:
		at += m.global_position - m.position_at(0)
	return at


func lane(lane_id: String) -> Dictionary:
	for l in data.get("lanes", []):
		if l["id"] == lane_id:
			return l
	return {}


func region_at(pos: Vector3) -> String:
	for r in data.get("regions", []):
		if pos.x >= r["x"][0] and pos.x <= r["x"][1] and pos.z >= r["z"][0] and pos.z <= r["z"][1]:
			return r["id"]
	return "elsewhere"


func _material(tag: String) -> StandardMaterial3D:
	if not _materials.has(tag):
		var m := StandardMaterial3D.new()
		m.albedo_color = TAG_COLORS.get(tag, Color(0.6, 0.6, 0.6))
		m.roughness = 0.85
		# A one-meter grid, so a frame shows sizes and speed. The meshes carry
		# texture coordinates in meters (cheaper to draw than triplanar mapping).
		if grid:
			m.albedo_texture = _grid_texture()
			m.uv1_scale = Vector3(0.5, 0.5, 0.5)
		_materials[tag] = m
	return _materials[tag]


func _grid_texture() -> ImageTexture:
	if _grid == null:
		var n := 128
		var img := Image.create_empty(n, n, true, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var line := x < 3 or y < 3
				var tile := ((x * 2 / n) + (y * 2 / n)) % 2 == 0
				var v := 0.62 if line else (1.0 if tile else 0.9)
				img.set_pixel(x, y, Color(v, v, v))
		img.generate_mipmaps()
		_grid = ImageTexture.create_from_image(img)
	return _grid


func _piece_transform(p: Dictionary) -> Transform3D:
	var rot: Array = p.get("rot_deg", [0, 0, 0])
	var b := Basis.from_euler(Vector3(deg_to_rad(float(rot[0])), deg_to_rad(float(rot[1])), deg_to_rad(float(rot[2]))))
	return Transform3D(b, _v3(p["center"]))


func _add_box(body: Node3D, p: Dictionary, local := false) -> void:
	var size := _v3(p["size"])
	var xf := Transform3D.IDENTITY if local else _piece_transform(p)
	var cs := CollisionShape3D.new()
	cs.name = String(p["id"])
	var shape := BoxShape3D.new()
	shape.size = size
	shape.margin = EDGE_MARGIN
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = String(p["id"]) + "-mesh"
	# Unturned boxes take their grid from world space, so it runs unbroken
	# from one block to the next.
	var turned: bool = local or p.has("rot_deg")
	mi.mesh = _box_mesh(size, Vector3.ZERO if turned else xf.origin)
	mi.material_override = _material(String(p.get("tag", "ground")))
	mi.transform = xf
	body.add_child(mi)


## A box whose texture coordinates are meters along each face.
func _box_mesh(size: Vector3, world_offset: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	# Each face: its normal and the two axes that span it.
	for f in [[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
			[Vector3.BACK, Vector3.RIGHT, Vector3.DOWN], [Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN],
			[Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN], [Vector3.LEFT, Vector3.BACK, Vector3.DOWN]]:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := n * h
		var corners := [c - u * h - v * h, c + u * h - v * h, c + u * h + v * h, c - u * h + v * h]
		for i in [0, 1, 2, 0, 2, 3]:
			var at: Vector3 = corners[i]
			var w := at + world_offset
			st.set_normal(n)
			st.set_uv(Vector2(w.dot(u.abs()), w.dot(v.abs())))
			st.add_vertex(at)
	return st.commit()


func _add_mover(p: Dictionary) -> void:
	var m := MovingSurface.new()
	m.name = String(p["id"])
	m.travel = _v3(p["travel"])
	m.period_ticks = int(p["period_ticks"])
	m.phase_ticks = int(p.get("phase_ticks", 0))
	m.position = _v3(p["center"])
	_add_box(m, p, true)
	add_child(m)
	movers[String(p["id"])] = m


func _add_heightfield(p: Dictionary) -> void:
	var nx := int(p["cells"][0])
	var nz := int(p["cells"][1])
	var cell := float(p.get("cell", 1.0))
	var heights := PackedFloat32Array()
	for h in p["heights"]:
		heights.append(float(h))
	var body := StaticBody3D.new()
	body.name = String(p["id"])
	body.position = _v3(p["center"])
	var cs := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	shape.map_data = heights
	cs.shape = shape
	cs.scale = Vector3(cell, 1.0, cell)
	body.add_child(cs)
	# The same heights as a mesh, so what is seen is what is collided with.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := -0.5 * (nx - 1) * cell
	var z0 := -0.5 * (nz - 1) * cell
	for j in nz - 1:
		for i in nx - 1:
			var a := Vector3(x0 + i * cell, heights[j * nx + i], z0 + j * cell)
			var b := Vector3(x0 + (i + 1) * cell, heights[j * nx + i + 1], z0 + j * cell)
			var c := Vector3(x0 + i * cell, heights[(j + 1) * nx + i], z0 + (j + 1) * cell)
			var d := Vector3(x0 + (i + 1) * cell, heights[(j + 1) * nx + i + 1], z0 + (j + 1) * cell)
			for v in [a, b, c, b, d, c]:
				st.set_uv(Vector2(v.x, v.z))
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _material(String(p.get("tag", "terrain")))
	body.add_child(mi)
	add_child(body)


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
