extends Node
## NPCSpawner — autoload that places NPCs in the world from npc_placements.json.
##
## Call NPCSpawner.spawn_npcs_for_map(map_id, map_node) after loading a map.
## Call NPCSpawner.try_interact(facing_tile) from the player interact handler.
##
## NPC data format (data/npc_placements.json):
##   {
##     "MAP_LITTLEROOT_TOWN": [
##       {
##         "id":       "littleroot_twin",
##         "sprite":   "res://assets/sprites/npcs/twin_spriteframes.tres",
##         "x": 16, "y": 10,
##         "facing":   "down",
##         "movement": "wander",   // "static" | "look_around" | "wander"
##         "range_x":  1, "range_y": 2,
##         "speaker":  "Young Woman",
##         "dialogue": ["Line one.", "Line two."]
##       }
##     ]
##   }

const NPC_SCENE  := preload("res://actors/npcs/NPC.tscn")
const DATA_PATH  := "res://data/npc_placements.json"

## map_id → Array of NPC placement dicts (loaded once at startup).
var _placements: Dictionary = {}

## tile_pos (Vector2i) → NPC node, rebuilt each map load.
var _tile_map: Dictionary = {}

## All NPC nodes currently in the scene.  Freed when the map node is freed
## (NPCs are children of the map node, so this list is just for easy lookup).
var _active: Array = []

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if not f:
		push_warning("[NPCSpawner] data/npc_placements.json not found — no NPCs will spawn.")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_placements = parsed
		print("[NPCSpawner] Loaded placements for %d maps." % _placements.size())
	else:
		push_error("[NPCSpawner] Failed to parse npc_placements.json.")


# ── Public API ────────────────────────────────────────────────────────────────

## Instantiate all NPCs for map_id as children of map_node.
## NPCs are freed automatically when map_node is queue_free'd.
func spawn_npcs_for_map(map_id: String, map_node: Node) -> void:
	_tile_map.clear()
	_active.clear()

	var entries: Array = _placements.get(map_id, [])
	for entry in entries:
		var tx: int = int(entry.get("x", 0))
		var ty: int = int(entry.get("y", 0))
		var npc: CharacterBody2D = NPC_SCENE.instantiate()
		# Set position BEFORE add_child so NPC._ready() captures the correct _origin.
		npc.position = Vector2(tx, ty) * 16.0 + Vector2(8.0, 8.0)
		map_node.add_child(npc)

		npc.npc_id       = str(entry.get("id", ""))
		npc.facing       = str(entry.get("facing", "down"))
		npc.movement     = str(entry.get("movement", "static"))
		npc.range_x      = int(entry.get("range_x", 0))
		npc.range_y      = int(entry.get("range_y", 0))
		npc.speaker_name = str(entry.get("speaker", ""))
		npc.dialogue     = Array(entry.get("dialogue", []))
		npc.set_sprite_frames(str(entry.get("sprite", "")))

		_tile_map[Vector2i(tx, ty)] = npc
		_active.append(npc)

	if not entries.is_empty():
		print("[NPCSpawner] Spawned %d NPC(s) for %s." % [entries.size(), map_id])


## Called by MainGame when the player presses the interact button.
## facing_tile is the tile directly in front of the player.
## Returns true if an NPC was found and dialogue was triggered.
func try_interact(facing_tile: Vector2i, player_pos: Vector2) -> bool:
	var npc = _tile_map.get(facing_tile)
	if not npc or not is_instance_valid(npc):
		return false
	# Turn the NPC to face the player before speaking.
	npc.face_toward(player_pos)
	npc.speak()
	return true
