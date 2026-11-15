extends SceneTree
## Build-time terrain builder (decision landforms). Run headless:
##   godot --headless --path game --script <repo>/tools/gen/build_terrain.gd -- --dir res://look_slice/generated
## Reads terrain.json + heights_*.f32 written by tools/gen/terrain.py and saves
## chunk meshes with LODs, the collision heightmap, the backdrop mesh and a
## terrain scene that ties them together. Deterministic: same input, same output.

const CHUNK := 64
const SKIRT := 2.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "res://look_slice/generated"
	if "--dir" in args:
		dir = args[args.find("--dir") + 1]
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("terrain.json")))
	var roam := _read_f32(dir.path_join(meta["roam"]["file"]))
	var n: int = int(meta["roam"]["size"][0])
	var far := _read_f32(dir.path_join(meta["far"]["file"]))
	var fw: int = int(meta["far"]["size"][0])
	var fh: int = int(meta["far"]["size"][1])
	var fstep: float = float(meta["far"]["step_m"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir.path_join("chunks")))
	var root := Node3D.new()
	root.name = "Terrain"
	var half := (n - 1) / 2.0
	# Roam chunks: 1 m grid, origin at the square's centre, +x east, +z south.
	var chunks := Node3D.new()
	chunks.name = "Chunks"
	root.add_child(chunks)
	chunks.owner = root
	var count := 0
	for cz in range(0, n - 1, CHUNK):
		for cx in range(0, n - 1, CHUNK):
			var mesh := _chunk_mesh(roam, n, cx, cz, mini(CHUNK, n - 1 - cx), mini(CHUNK, n - 1 - cz), half)
			var path := dir.path_join("chunks/c_%d_%d.res" % [cx / CHUNK, cz / CHUNK])
			ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
			var mi := MeshInstance3D.new()
			mi.name = "c_%d_%d" % [cx / CHUNK, cz / CHUNK]
			mi.mesh = load(path)
			chunks.add_child(mi)
			mi.owner = root
			count += 1
	# Collision from the same heights at the same 1 m spacing.
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = roam
	ResourceSaver.save(shape, dir.path_join("collision.res"), ResourceSaver.FLAG_COMPRESS)
	var body := StaticBody3D.new()
	body.name = "Ground"
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = load(dir.path_join("collision.res"))
	body.add_child(cs)
	root.add_child(body)
	body.owner = root
	cs.owner = root
	# Backdrop: the wider window, with the roam square cut out (no z-fighting),
	# placed so both share the same ground under the roam square's edges.
	var off: Array = meta["far"]["roam_offset_m"]
	var far_mesh := _far_mesh(far, fw, fh, fstep, Vector2(float(off[0]), float(off[1])), half)
	ResourceSaver.save(far_mesh, dir.path_join("far.res"), ResourceSaver.FLAG_COMPRESS)
	var fmi := MeshInstance3D.new()
	fmi.name = "Backdrop"
	fmi.mesh = load(dir.path_join("far.res"))
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fmi)
	fmi.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, dir.path_join("terrain.tscn"))
	print("BUILD_TERRAIN chunks=%d n=%d far=%dx%d" % [count, n, fw, fh])
	root.free()
	quit(0)


func _read_f32(path: String) -> PackedFloat32Array:
	return FileAccess.get_file_as_bytes(path).to_float32_array()


func _h(data: PackedFloat32Array, w: int, x: int, z: int) -> float:
	return data[z * w + x]


func _chunk_mesh(h: PackedFloat32Array, n: int, x0: int, z0: int, cw: int, ch: int, half: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for z in range(z0, z0 + ch + 1):
		for x in range(x0, x0 + cw + 1):
			verts.append(Vector3(x - half, _h(h, n, x, z), z - half))
			var l := _h(h, n, maxi(x - 1, 0), z)
			var r := _h(h, n, mini(x + 1, n - 1), z)
			var u := _h(h, n, x, maxi(z - 1, 0))
			var d := _h(h, n, x, mini(z + 1, n - 1))
			norms.append(Vector3(l - r, 2.0, u - d).normalized())
			uvs.append(Vector2(x, z) / float(n - 1))
	var row := cw + 1
	for z in ch:
		for x in cw:
			var i := z * row + x
			idx.append_array([i, i + 1, i + row, i + 1, i + row + 1, i + row])
	# Skirts hide cracks between chunks drawn at different LODs.
	var base := verts.size()
	var edge: Array[int] = []
	for x in cw + 1: edge.append(x)
	for z in ch + 1: edge.append(z * row + cw)
	for x in range(cw, -1, -1): edge.append(ch * row + x)
	for z in range(ch, -1, -1): edge.append(z * row)
	for k in edge.size():
		var v := verts[edge[k]]
		verts.append(v - Vector3(0, SKIRT, 0))
		norms.append(norms[edge[k]])
		uvs.append(uvs[edge[k]])
	for k in edge.size() - 1:
		var a := edge[k]
		var b := edge[k + 1]
		var a2 := base + k
		var b2 := base + k + 1
		idx.append_array([a, a2, b, b, a2, b2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


func _far_mesh(h: PackedFloat32Array, w: int, d: int, step: float, roam_off: Vector2, half: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	# Backdrop coordinates: its NW corner at -(roam_off + half) from the roam centre.
	var origin := Vector2(-roam_off.x - half, -roam_off.y - half)
	for z in d:
		for x in w:
			verts.append(Vector3(origin.x + x * step, _h(h, w, x, z) - 0.5, origin.y + z * step))
	var roam_rect := Rect2(-half + step, -half + step, 2 * half - 2 * step, 2 * half - 2 * step)
	for z in d - 1:
		for x in w - 1:
			var c := Vector2(origin.x + (x + 0.5) * step, origin.y + (z + 0.5) * step)
			if roam_rect.has_point(c):
				continue
			var i := z * w + x
			idx.append_array([i, i + 1, i + w, i + 1, i + w + 1, i + w])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in verts:
		st.add_vertex(v)
	for i in idx:
		st.add_index(i)
	st.generate_normals()
	var arrays := st.commit_to_arrays()
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()
