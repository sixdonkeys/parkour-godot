extends Node
## Assets (autoload): resolves source textures to the active profile's tier
## copy, made at build time under res://assets/_tiers/<tier>/ (decision
## quality-profiles). Falls back to the source when no tier copy exists.

func texture(source_path: String) -> Texture2D:
	var tier: String = ""
	if has_node("/root/Game") and get_node("/root/Game").quality:
		tier = get_node("/root/Game").quality.texture_tier
	if not tier.is_empty() and source_path.begins_with("res://assets/"):
		var tiered := source_path.replace("res://assets/", "res://assets/_tiers/%s/" % tier)
		if ResourceLoader.exists(tiered):
			return load(tiered)
	return load(source_path)
