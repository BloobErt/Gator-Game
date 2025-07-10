# GameManager.gd - New data-driven version
extends Node

# === RESOURCES (Auto-loaded) ===
var game_config: GameConfig
var current_level_data: LevelData
var shop_config: ShopConfig
var ui_config: UIConfig
var audio_config: AudioConfig
var all_level_data: Array[LevelData] = []

# === MANAGERS ===
@onready var progression_manager = $ProgressionManager
@onready var economy_manager = $EconomyManager  
@onready var tooth_manager = $ToothManager
@onready var effect_manager = $EffectManager
@onready var ui_manager = $UIManager
@onready var audio_manager = $AudioManager

# === UI REFERENCES ===
@onready var round_transition = $RoundTransition
@onready var shop = $Shop
@onready var game_ui = $GameUI

# === CORE GAME STATE ===
var current_level: int = 1
var current_round: int = 1
var round_score: int = 0
var total_score: int = 0

# === SIGNALS ===
signal level_completed(level_number: int, score: int)
signal round_completed(round_number: int, score: int)
signal game_over(final_score: int)
signal background_frame_sync
signal shop_loop_sync

func emit_3d_frame_sync():
	emit_signal("background_frame_sync")

func emit_shop_loop_sync():
	emit_signal("shop_loop_sync")

# Add signal handlers to respond to animation events
func _on_background_sync():
	# This is called by the 3D background animation loop
	# You can add any per-frame sync logic here
	pass

func _on_shop_sync():
	# This is called by the shop animation loop
	# You can add any shop-specific sync logic here
	pass

func _ready():
	load_all_configs()
	setup_managers()
	
	# FIX: Ensure 3D scene is visible and 2D background is hidden
	setup_scene_visibility()
	
	start_game()

# === CONFIGURATION LOADING ===
func load_all_configs():
	print("Loading game configurations...")
	
	# Load main config
	game_config = load_or_create_config("res://Data/game_config.tres", GameConfig)
	shop_config = load_or_create_config("res://Data/shop_config.tres", ShopConfig)
	ui_config = load_or_create_config("res://Data/ui_config.tres", UIConfig)
	audio_config = load_or_create_config("res://Data/audio_config.tres", AudioConfig)
	
	# Load all level data
	load_level_configurations()
	
	# FIX: Load tattoos and artifacts from Data folder
	load_tattoo_and_artifact_data()
	
	print("✅ All configurations loaded successfully")

func load_tattoo_and_artifact_data():
	print("Loading tattoo and artifact data...")
	
	# Load tattoos from Data folder
	var tattoo_folder = "res://Data/"
	var dir = DirAccess.open(tattoo_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with("tattoo") and file_name.ends_with(".tres"):
				var full_path = tattoo_folder + file_name
				var tattoo_data = load(full_path)
				if tattoo_data is TattooData:
					print("✅ Found tattoo: ", tattoo_data.name)
			if file_name.begins_with("artifact") and file_name.ends_with(".tres"):
				var full_path = tattoo_folder + file_name
				var artifact_data = load(full_path)
				if artifact_data is ArtifactData:
					print("✅ Found artifact: ", artifact_data.name)
			file_name = dir.get_next()
		dir.list_dir_end()

func load_or_create_config(path: String, config_class) -> Resource:
	if ResourceLoader.exists(path):
		var config = load(path)
		print("✅ Loaded: ", path)
		return config
	else:
		print("⚠️ Config not found, creating default: ", path)
		var new_config = config_class.new()
		
		# Ensure directory exists
		var dir_path = path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.open("res://").make_dir_recursive(dir_path)
		
		# Save default config
		ResourceSaver.save(new_config, path)
		return new_config

func load_level_configurations():
	all_level_data.clear()
	var levels_dir = "res://Data/Levels/"
	
	# Create levels directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(levels_dir):
		DirAccess.open("res://").make_dir_recursive(levels_dir)
		create_default_levels()
	
	# Load existing level files
	var dir = DirAccess.open(levels_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var level_data = load(levels_dir + file_name)
				if level_data is LevelData:
					all_level_data.append(level_data)
					print("✅ Loaded level: ", level_data.display_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# Sort by level number
	all_level_data.sort_custom(func(a, b): return a.level_number < b.level_number)
	
	# Create missing levels if we don't have enough
	while all_level_data.size() < game_config.max_levels:
		create_level(all_level_data.size() + 1)

func create_default_levels():
	print("Creating default level configurations...")
	for i in range(1, game_config.max_levels + 1):
		create_level(i)

func create_level(level_num: int):
	var level_data = LevelData.new()
	level_data.level_number = level_num
	level_data.display_name = "Level " + str(level_num)
	level_data.target_score = int(game_config.base_score_target * pow(game_config.score_multiplier_per_level, level_num - 1))
	level_data.tooth_value_min = game_config.base_tooth_value_min + (level_num - 1) * 2
	level_data.tooth_value_max = game_config.base_tooth_value_max + (level_num - 1) * 5
	level_data.num_multiplier_teeth = min(2 + (level_num - 1) / 3, 5)
	level_data.completion_money_bonus = 25 * level_num
	
	var file_path = "res://Data/Levels/level_" + str(level_num) + ".tres"
	ResourceSaver.save(level_data, file_path)
	all_level_data.append(level_data)
	print("✅ Created level ", level_num, " with target score: ", level_data.target_score)

func setup_scene_visibility():
	print("🔍 DEBUG: setup_scene_visibility() called")
	
	# Hide the 2D background initially so we can see the 3D scene
	var bg_2d = get_node_or_null("Camera3D/Background/TextureRect")
	if bg_2d:
		bg_2d.modulate.a = 0.0
		print("✅ DEBUG: 2D background hidden, alpha = ", bg_2d.modulate.a)
	
	# Make sure alligator is visible
	var alligator = get_node_or_null("Alligator") 
	if alligator:
		alligator.visible = true
		print("✅ DEBUG: Alligator visible = ", alligator.visible)
	
	# Camera debug
	var camera = get_node_or_null("Camera3D")
	if camera:
		print("✅ DEBUG: Camera found at: ", camera.global_position)
	
	# START THE 3D BACKGROUND ANIMATION
	start_3d_background_animation()

# === MANAGER SETUP ===
func setup_managers():
	# Pass configs to managers
	if progression_manager:
		progression_manager.setup(game_config, all_level_data)
	if economy_manager:
		economy_manager.setup(game_config, shop_config)
	if tooth_manager:
		tooth_manager.setup(game_config, $Alligator)
	if effect_manager:
		effect_manager.setup(game_config, ui_config)
	if ui_manager:
		ui_manager.setup(ui_config, $GameUI, $RoundTransition)
	if audio_manager:
		audio_manager.setup(audio_config)
	
	# Connect manager signals
	connect_manager_signals()
	
	# Connect background animation signals
	connect_background_signals()

func connect_manager_signals():
	if progression_manager:
		progression_manager.level_completed.connect(_on_level_completed)
		progression_manager.round_completed.connect(_on_round_completed)
	
	if economy_manager:
		economy_manager.shop_transaction.connect(_on_shop_transaction)
	
	if tooth_manager:
		tooth_manager.tooth_pressed.connect(_on_tooth_pressed)
		tooth_manager.bite_tooth_hit.connect(_on_bite_tooth_hit)
	
	if ui_manager:
		ui_manager.continue_to_shop.connect(_on_continue_to_shop)
		ui_manager.shop_closed.connect(_on_shop_closed)

func connect_background_signals():
	# Define the signals first
	if not has_signal("background_frame_sync"):
		add_user_signal("background_frame_sync")
	
	if not has_signal("shop_loop_sync"):
		add_user_signal("shop_loop_sync")
	
	# Connect to the signal handlers
	background_frame_sync.connect(_on_background_sync)
	shop_loop_sync.connect(_on_shop_sync)
	
	print("✅ Background animation signals connected")

# === GAME FLOW ===
func start_game():
	current_level = 1
	current_round = 1
	total_score = 0
	
	load_level(current_level)
	start_round()

func load_level(level_number: int):
	if level_number <= all_level_data.size():
		current_level_data = all_level_data[level_number - 1]
		current_level = level_number
		
		print("=== LOADED LEVEL ", level_number, " ===")
		print("Target Score: ", current_level_data.target_score)
		print("Tooth Values: ", current_level_data.tooth_value_min, "-", current_level_data.tooth_value_max)
		
		# Apply level configuration to managers
		if tooth_manager:
			tooth_manager.configure_for_level(current_level_data)
		if ui_manager:
			ui_manager.update_level_display(current_level_data)
	else:
		print("❌ Level ", level_number, " not found!")

func start_round():
	round_score = 0
	current_round = progression_manager.get_current_round()
	
	print("=== STARTING ROUND ", current_round, " ===")
	
	# Configure systems for new round
	if tooth_manager:
		tooth_manager.start_new_round(current_level_data)
	if ui_manager:
		ui_manager.start_round(current_round, game_config.max_rounds_per_level)
	
	update_ui()

func start_3d_background_animation():
	# Start the 3D background animation
	var bg_3d_anim = get_node_or_null("Camera3D/dBackground/AnimationPlayer")
	if bg_3d_anim:
		bg_3d_anim.play("game_loop_3d")
		print("✅ Started 3D background animation")
	else:
		print("❌ Could not find 3D background AnimationPlayer")
	
	# Start the 2D background animation tree in game mode
	var bg_2d_anim_tree = get_node_or_null("Camera3D/Background/AnimationTree")
	if bg_2d_anim_tree:
		bg_2d_anim_tree.active = true
		var playback = bg_2d_anim_tree.get("parameters/playback")
		playback.travel("game_loop")
		print("✅ Started 2D background AnimationTree in game_loop mode")
	else:
		print("❌ Could not find 2D background AnimationTree")

# === EVENT HANDLERS ===
func _on_tooth_pressed(tooth_name: String, score_value: int):
	round_score += score_value
	
	# Show score popup
	if ui_manager:
		var tooth_position = tooth_manager.get_tooth_world_position(tooth_name)
		ui_manager.show_score_popup(score_value, tooth_position)
	
	# Play audio
	if audio_manager:
		audio_manager.play_tooth_click()
	
	update_ui()

func _on_bite_tooth_hit(tooth_name: String):
	print("💀 BITE TOOTH HIT: ", tooth_name)
	
	# Apply penalty
	var penalty = int(round_score * game_config.bite_penalty_percentage)
	round_score = max(0, round_score - penalty)
	print("💰 Penalty applied: -", penalty, " (New score: ", round_score, ")")
	
	# Check for bite survival artifacts
	var can_continue = effect_manager.handle_bite_survival()
	
	if audio_manager:
		audio_manager.play_bite_sound()
	
	if can_continue:
		print("✨ Bite survival activated!")
		if ui_manager:
			ui_manager.show_bite_survival_message()
	else:
		print("🎬 Ending round due to bite...")
		end_round()  # This should now properly show transition

func _on_level_completed(level_number: int, final_score: int):
	print("🎉 LEVEL ", level_number, " COMPLETED with score: ", final_score)
	
	# Award completion bonus
	if economy_manager:
		economy_manager.award_completion_bonus(current_level_data.completion_money_bonus)
	
	# Check if game is complete
	if level_number >= game_config.max_levels:
		emit_signal("game_over", total_score)
	else:
		# Move to next level
		load_level(level_number + 1)
		current_round = 1
		start_round()

func _on_round_completed(round_number: int, score: int):
	total_score += score
	
	# Check if level is complete
	if progression_manager.is_level_complete(total_score, current_level_data.target_score):
		emit_signal("level_completed", current_level, total_score)
	elif round_number >= game_config.max_rounds_per_level:
		# Out of rounds but didn't hit target - game over or retry
		emit_signal("game_over", total_score)
	else:
		# Continue to shop then next round
		show_round_transition()

func _on_continue_to_shop():
	print("🛒 Opening shop...")
	
	# Transition AnimationTree to shop mode
	var bg_2d_anim_tree = get_node_or_null("Camera3D/Background/AnimationTree")
	if bg_2d_anim_tree:
		var playback = bg_2d_anim_tree.get("parameters/playback")
		playback.travel("shop_loop")
		print("🛒 Started shop_loop animation")
	
	if economy_manager and ui_manager:
		var money = economy_manager.get_current_money()
		ui_manager.open_shop(money, shop_config)

func _on_shop_closed(teeth_mapping: Dictionary, purchased_artifacts: Array):
	print("🛒 Shop closed, returning to game...")
	
	# Apply new tattoos and artifacts
	if tooth_manager:
		tooth_manager.apply_tattoo_mapping(teeth_mapping)
	if effect_manager:
		effect_manager.add_artifacts(purchased_artifacts)
	
	# RESUME the 3D background animation
	var bg_3d_anim = get_node_or_null("Camera3D/dBackground/AnimationPlayer")
	if bg_3d_anim:
		bg_3d_anim.play("game_loop_3d")  # Resume/restart the 3D animation
		print("▶️ Resumed 3D background animation")
	
	# Transition back to game mode in AnimationTree
	var bg_2d_anim_tree = get_node_or_null("Camera3D/Background/AnimationTree")
	if bg_2d_anim_tree:
		var playback = bg_2d_anim_tree.get("parameters/playback")
		playback.travel("transition_to_game")
		print("🎮 Started transition_to_game animation")
	
	# The 2D background will be hidden by the transition animation
	# Hide it immediately for now
	var bg_2d = get_node_or_null("Camera3D/Background/TextureRect")
	if bg_2d:
		bg_2d.modulate.a = 0.0
		print("✅ Returned to 3D view")
	
	# Start next round
	current_round += 1
	start_round()

func _on_shop_transaction(cost: int, item_type: String):
	print("💰 Shop transaction: ", cost, " gold for ", item_type)

# === UI UPDATES ===
func update_ui():
	if not ui_manager:
		return
	
	ui_manager.update_score(round_score)
	ui_manager.update_total_score(total_score, current_level_data.target_score)
	ui_manager.update_round(current_round, game_config.max_rounds_per_level)
	ui_manager.update_level(current_level)
	
	if economy_manager:
		ui_manager.update_money(economy_manager.get_current_money())

func show_round_transition():
	print("🎬 Showing round transition...")
	
	# Check if round_transition exists
	if not round_transition:
		round_transition = get_node_or_null("RoundTransition")
		if not round_transition:
			print("❌ DEBUG: RoundTransition node not found!")
			return
	
	# PAUSE the 3D background during transition
	var bg_3d_anim = get_node_or_null("Camera3D/dBackground/AnimationPlayer")
	if bg_3d_anim:
		bg_3d_anim.pause()
		print("⏸️ Paused 3D background animation")
	
	# Start transition to shop in AnimationTree
	var bg_2d_anim_tree = get_node_or_null("Camera3D/Background/AnimationTree")
	if bg_2d_anim_tree:
		var playback = bg_2d_anim_tree.get("parameters/playback")
		playback.travel("transition_to_shop")
		print("🎬 Started transition_to_shop animation")
	
	# Show the 2D background for transition
	var bg_2d = get_node_or_null("Camera3D/Background/TextureRect")
	if bg_2d:
		bg_2d.modulate.a = 1.0
		print("✅ 2D background shown for transition")
	
	# Calculate money earned and show transition
	var money_earned = economy_manager.calculate_round_money(round_score)
	if round_transition and round_transition.has_method("show_results"):
		round_transition.show_results(round_score, money_earned, total_score, current_level_data.target_score)

func end_round():
	total_score += round_score
	economy_manager.award_round_money(round_score)
	
	# FIX: Show the round transition screen
	show_round_transition()
	
	emit_signal("round_completed", current_round, round_score)

# === UTILITY ===
func get_current_config() -> GameConfig:
	return game_config

func get_current_level_config() -> LevelData:
	return current_level_data

# === DEBUG ===
func _input(event):
	if not game_config or not game_config.debug_mode:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				print("=== DEBUG: Current Game State ===")
				print("Level: ", current_level, " Round: ", current_round)
				print("Score: ", round_score, "/", total_score)
				print("Target: ", current_level_data.target_score if current_level_data else "No level data")
			KEY_F2:
				if economy_manager:
					economy_manager.add_debug_money(1000)
					update_ui()
			KEY_F3:
				current_round = game_config.max_rounds_per_level
				end_round()
