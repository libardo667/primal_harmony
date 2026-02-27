class_name ZoneData extends RefCounted

var zone_id: String
var zone_name: String
var zone_number: int
var dominant_type: String
var location: String
var ehi_local: float
var ehi_thresholds: Dictionary = {}
var encounter_table: Dictionary = {}
var native_species: Array[String] = []
var corrupted_variants: Array[String] = []
var quell_types: Array[String] = []
var traversal_hazards: Array = []
var key_items: Array[String] = []
var relocation_terminals: Array[String] = []
var ehi_restoration_effect: String
var narrative_role: String
var story_gate: Variant # Dictionary or null

func _init(data: Dictionary) -> void:
	zone_id = data.get("zone_id", "")
	zone_name = data.get("zone_name", "")
	zone_number = data.get("zone_number", 0)
	dominant_type = data.get("dominant_type", "")
	location = data.get("location", "")
	ehi_local = float(data.get("ehi_local", 0.0))
	ehi_thresholds = data.get("ehi_thresholds", {})
	encounter_table = data.get("encounter_table", {})
	
	for s in data.get("native_species", []):
		native_species.append(s)
		
	for c in data.get("corrupted_variants", []):
		corrupted_variants.append(c)
		
	for q in data.get("quell_types", []):
		quell_types.append(q)
		
	traversal_hazards = data.get("traversal_hazards", [])
	
	for k in data.get("key_items", []):
		key_items.append(k)
		
	for r in data.get("relocation_terminals", []):
		relocation_terminals.append(r)
		
	ehi_restoration_effect = data.get("ehi_restoration_effect", "")
	narrative_role = data.get("narrative_role", "")
	story_gate = data.get("story_gate", null)
