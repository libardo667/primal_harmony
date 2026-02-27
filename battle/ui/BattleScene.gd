## BattleScene.gd — UI hook for BattleManager
##
## Collects signals from BattleManager and orchestrates animations,
## text display, and menu states.
##
## Bottom panel is a single always-visible node (BottomPanel) containing:
##   - Text label (top-left): current battle message
##   - BtnFlee / BtnParty / BtnBag (horizontal row, bottom-left)
##   - Move1…Move4 (2x2 fixed grid, right side)
extends CanvasLayer

@onready var bg_texture: TextureRect = $Background
@onready var player_sprite: TextureRect = $PlayerAnchor/Sprite
@onready var enemy_sprite: TextureRect = $EnemyAnchor/Sprite

# Unified bottom panel
@onready var bottom_panel: TextureRect = $BottomPanel
@onready var dialogue_box: Label = $BottomPanel/Text

# Enemy HUD
@onready var enemy_name_label: Label = $EnemyHUD/NameLabel
@onready var enemy_level_label: Label = $EnemyHUD/LevelLabel
@onready var enemy_hp_bar: TextureProgressBar = $EnemyHUD/HPBar
@onready var enemy_status: TextureRect = $EnemyHUD/StatusIcon

# Player HUD
@onready var player_name_label: Label = $PlayerHUD/NameLabel
@onready var player_level_label: Label = $PlayerHUD/LevelLabel
@onready var player_hp_bar: TextureProgressBar = $PlayerHUD/HPBar
@onready var player_hp_label: Label = $PlayerHUD/HPLabel
@onready var player_exp_bar: ProgressBar = $PlayerHUD/ExpBar
@onready var player_status: TextureRect = $PlayerHUD/StatusIcon

# Command buttons
@onready var btn_flee: Button = $BottomPanel/BtnFlee
@onready var btn_party: Button = $BottomPanel/BtnParty
@onready var btn_bag: Button = $BottomPanel/BtnBag

# Move buttons — fixed positions
@onready var btn_move1: Button = $BottomPanel/Move1
@onready var btn_move2: Button = $BottomPanel/Move2
@onready var btn_move3: Button = $BottomPanel/Move3
@onready var btn_move4: Button = $BottomPanel/Move4

var _is_animating: bool = false
var _queued_messages: Array[String] = []
## 0-3 = moves, 4 = flee, 5 = party, 6 = bag
var _cursor_index: int = 0
var _awaiting_input: bool = false


func _ready() -> void:
	# Connect to BattleManager signals.
	BattleManager.battle_started.connect(_on_battle_started)
	BattleManager.battle_ended.connect(_on_battle_ended)
	BattleManager.turn_started.connect(_on_turn_started)
	BattleManager.move_used.connect(_on_move_used)
	BattleManager.damage_dealt.connect(_on_damage_dealt)
	BattleManager.status_applied.connect(_on_status_applied)
	BattleManager.pokemon_fainted.connect(_on_pokemon_fainted)
	BattleManager.level_up.connect(_on_level_up)

	# Wire move buttons.
	btn_move1.pressed.connect(func(): _on_move_pressed(0))
	btn_move2.pressed.connect(func(): _on_move_pressed(1))
	btn_move3.pressed.connect(func(): _on_move_pressed(2))
	btn_move4.pressed.connect(func(): _on_move_pressed(3))

	# Wire command buttons.
	btn_flee.pressed.connect(_on_flee_pressed)
	btn_party.pressed.connect(_on_party_pressed)
	btn_bag.pressed.connect(_on_bag_pressed)

	# Keyboard cursor owns selection — no mouse/tab focus on any button.
	for btn: Button in [btn_move1, btn_move2, btn_move3, btn_move4, btn_flee, btn_party, btn_bag]:
		btn.focus_mode = Control.FOCUS_NONE

	_set_input_enabled(false)
	hide()

	# Keep running while the scene tree is paused (during battle).
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Scale the 240x160 GBA layout to fill the actual window.
	_apply_viewport_scale()
	get_viewport().size_changed.connect(_apply_viewport_scale)


func _apply_viewport_scale() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	transform = Transform2D(Vector2(vp.x / 240.0, 0.0), Vector2(0.0, vp.y / 160.0), Vector2.ZERO)


func _process(_delta: float) -> void:
	if not _is_animating and not _queued_messages.is_empty():
		_display_next_message()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Advance dialogue on ui_accept while waiting for player.
	if _awaiting_input and event.is_action_pressed("ui_accept"):
		_advance_dialogue()
		get_viewport().set_input_as_handled()
		return
	# Move menu keyboard navigation — only when buttons are enabled.
	if btn_flee.disabled:
		return
	var is_next: bool = event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down") \
		or event.is_action_pressed("move_right") or event.is_action_pressed("move_down")
	var is_prev: bool = event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up") \
		or event.is_action_pressed("move_left") or event.is_action_pressed("move_up")
	if is_next:
		_cursor_index = (_cursor_index + 1) % 7
		_update_cursor()
		get_viewport().set_input_as_handled()
	elif is_prev:
		_cursor_index = (_cursor_index - 1 + 7) % 7
		_update_cursor()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		match _cursor_index:
			4: _on_flee_pressed()
			5: _on_party_pressed()
			6: _on_bag_pressed()
			_: _on_move_pressed(_cursor_index)
		get_viewport().set_input_as_handled()


# --- BattleManager Signal Handlers ---

func _on_battle_started(context: Dictionary) -> void:
	get_tree().paused = true
	show()
	bottom_panel.show()
	_set_input_enabled(false)
	var zone_id: String = context.get("zone_id", "")
	_set_background_for_zone(zone_id)
	_update_hud()
	_queue_message("A wild battle began!")


func _on_battle_ended(result: Dictionary) -> void:
	_set_input_enabled(false)
	var outcome: String = result.get("outcome", "")
	if outcome == "win":
		_queue_message("You won the battle!")
	elif outcome == "loss":
		_queue_message("You wiped out...")

	await get_tree().create_timer(2.0).timeout
	hide()
	get_tree().paused = false


func _on_turn_started(_turn: int) -> void:
	_cursor_index = 0
	_update_hud()
	_set_input_enabled(true)
	_populate_moves()


func _on_move_used(action: Dictionary) -> void:
	_set_input_enabled(false)
	var actor: String = action.get("species_id", "Unknown")
	var move: String = action.get("move_name", "a move")
	_queue_message("%s used %s!" % [actor, move])


func _on_damage_dealt(event: Dictionary) -> void:
	_update_hud()
	var eff: float = event.get("type_effectiveness", 1.0)
	if eff > 1.0:
		_queue_message("It's super effective!")
	elif eff < 1.0 and eff > 0.0:
		_queue_message("It's not very effective...")
	elif eff == 0.0:
		_queue_message("It had no effect!")
	if event.get("is_critical", false):
		_queue_message("A critical hit!")


func _on_status_applied(event: Dictionary) -> void:
	_update_hud()
	var status: String = event.get("status", "")
	_queue_message("Inflicted with %s!" % status)


func _on_pokemon_fainted(event: Dictionary) -> void:
	_update_hud()
	var species: String = event.get("species_id", "Unknown")
	_queue_message("%s fainted!" % species)


func _on_level_up(event: Dictionary) -> void:
	_update_hud()
	var species: String = event.get("species_id", "Unknown")
	var lvl: int = event.get("new_level", 1)
	_queue_message("%s grew to level %d!" % [species, lvl])


# --- Button Handlers ---

func _on_move_pressed(index: int) -> void:
	var player_state: Dictionary = BattleManager.get_player_active()
	var learnset: Array = player_state.get("learnset", [])
	if index < learnset.size():
		var move_id: String = learnset[index].get("move_id", "")
		BattleManager.player_use_move(move_id)


func _on_flee_pressed() -> void:
	BattleManager.player_flee()


func _on_party_pressed() -> void:
	var party: Array[Dictionary] = PlayerParty.get_party()
	if party.is_empty():
		_queue_message("Your party is empty!")
		return
	for entry: Dictionary in party:
		var sid: String = entry.get("species_id", "?")
		var pname: String = DataManager.get_pokemon_display_name(sid)
		_queue_message("%s  HP %d / %d" % [pname, entry.get("current_hp", 0), entry.get("max_hp", 1)])


func _on_bag_pressed() -> void:
	_queue_message("Bag -- not yet available.")


# --- Internal UI Logic ---

func _set_input_enabled(enabled: bool) -> void:
	btn_flee.disabled = not enabled
	btn_party.disabled = not enabled
	btn_bag.disabled = not enabled
	# Move buttons: only enable if they have real moves (not "-")
	if not enabled:
		for btn: Button in [btn_move1, btn_move2, btn_move3, btn_move4]:
			btn.disabled = true
	# When enabling, _populate_moves() handles move button states individually.


func _set_background_for_zone(zone_id: String) -> void:
	match zone_id:
		"ashen_glacier":
			bg_texture.texture = load("res://assets/sprites/ui/battle_bg_ashen_glacier.png")
		"the_murk":
			bg_texture.texture = load("res://assets/sprites/ui/battle_bg_the_murk.png")
		_:
			bg_texture.texture = load("res://assets/sprites/ui/battle_bg_default.png")


func _update_hud() -> void:
	var p: Dictionary = BattleManager.get_player_active()
	var e: Dictionary = BattleManager.get_opponent_active()

	if not p.is_empty():
		var sid_p: String = p.get("species_id", "")
		player_name_label.text = DataManager.get_pokemon_display_name(sid_p)
		player_level_label.text = "Lv.%d" % p.get("level", 1)
		player_hp_bar.max_value = p.get("max_hp", 1)
		player_hp_bar.value = p.get("current_hp", 1)
		player_hp_label.text = "%d / %d" % [p.get("current_hp", 1), p.get("max_hp", 1)]
		var lvl: int = p.get("level", 1)
		player_exp_bar.max_value = maxi(1, lvl * 100)
		player_exp_bar.value = p.get("exp", 0)
		_set_status_icon(player_status, p.get("status", ""))
		var p_tex: Texture2D = _load_sprite(sid_p, "back")
		if p_tex:
			player_sprite.texture = p_tex

	if not e.is_empty():
		var sid_e: String = e.get("species_id", "")
		enemy_name_label.text = DataManager.get_pokemon_display_name(sid_e)
		enemy_level_label.text = "Lv.%d" % e.get("level", 1)
		enemy_hp_bar.max_value = e.get("max_hp", 1)
		enemy_hp_bar.value = e.get("current_hp", 1)
		_set_status_icon(enemy_status, e.get("status", ""))
		var e_tex: Texture2D = _load_sprite(sid_e, "front")
		if e_tex:
			enemy_sprite.texture = e_tex


## Loads a Pokémon sprite, falling back to the standard path if PokemonData has no sprites field.
func _load_sprite(species_id: String, view: String) -> Texture2D:
	var pdata: PokemonData = DataManager.get_pokemon(species_id)
	var path: String = pdata.sprites.get(view, "") if pdata != null else ""
	if path.is_empty():
		path = "res://assets/sprites/pokemon/%s/%s.png" % [species_id, view]
	return load(path) as Texture2D


func _set_status_icon(rect: TextureRect, status: String) -> void:
	if status.is_empty() or status in ["flinch", "confusion"]:
		rect.texture = null
		return
	var path: String = "res://assets/sprites/ui/status_%s.png"
	match status:
		"burn":      rect.texture = load(path % "brn")
		"freeze":    rect.texture = load(path % "frz")
		"paralysis": rect.texture = load(path % "par")
		"poison":    rect.texture = load(path % "psn")
		"sleep":     rect.texture = load(path % "slp")


func _populate_moves() -> void:
	var p: Dictionary = BattleManager.get_player_active()
	var learnset: Array = p.get("learnset", [])
	var buttons: Array[Button] = [btn_move1, btn_move2, btn_move3, btn_move4]
	for i in range(4):
		if i < learnset.size():
			var mid: String = learnset[i].get("move_id", "")
			var mdata: MoveData = DataManager.get_move(mid)
			buttons[i].text = mdata.name if mdata != null else mid
			buttons[i].disabled = false
		else:
			buttons[i].text = "-"
			buttons[i].disabled = true
	_update_cursor()


func _update_cursor() -> void:
	var buttons: Array[Button] = [
		btn_move1, btn_move2, btn_move3, btn_move4,
		btn_flee, btn_party, btn_bag,
	]
	for i in range(buttons.size()):
		var lbl: String = buttons[i].text.trim_prefix("> ")
		buttons[i].text = ("> " if i == _cursor_index else "") + lbl


func _queue_message(msg: String) -> void:
	_queued_messages.append(msg)


func _display_next_message() -> void:
	if _queued_messages.is_empty():
		return
	_is_animating = true
	_awaiting_input = false
	dialogue_box.text = _queued_messages.pop_front()
	await get_tree().create_timer(0.6).timeout
	_awaiting_input = true


func _advance_dialogue() -> void:
	_awaiting_input = false
	_is_animating = false
