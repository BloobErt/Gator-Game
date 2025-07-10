# ToothManager.gd
# Handles all tooth-related logic, values, and interactions
extends Node

signal tooth_pressed(tooth_name: String, score_value: int)
signal bite_tooth_hit(tooth_name: String)

var game_config: GameConfig
var alligator_controller: Node3D
var current_level_data: LevelData

# Tooth data
var tooth_values: Dictionary = {}
var tooth_multipliers: Dictionary = {}
var tooth_tattoos: Dictionary = {}
var disabled_teeth: Array[String] = []
var safe_teeth: Array[String] = []

func setup(config: GameConfig, alligator: Node3D):
	game_config = config
	alligator_controller = alligator
	
	if alligator_controller:
		# Connect to alligator signals
		alligator_controller.tooth_pressed.connect(_on_alligator_tooth_pressed)
		alligator_controller.tooth_bit.connect(_on_alligator_tooth_bit)
		print("✅ ToothManager connected to alligator")
	else:
		print("❌ ToothManager: No alligator controller found!")

func configure_for_level(level_data: LevelData):
	current_level_data = level_data
	print("🦷 Configuring teeth for level ", level_data.level_number)

func start_new_round(level_data: LevelData):
	current_level_data = level_data
	disabled_teeth.clear()
	
	generate_tooth_values()
	assign_multiplier_teeth()
	
	if alligator_controller:
		alligator_controller.reset_teeth()
		alligator_controller.update_tooth_visuals(tooth_values, tooth_multipliers)

func generate_tooth_values():
	tooth_values.clear()
	
	var all_teeth = get_all_tooth_names()
	
	for tooth_name in all_teeth:
		var min_val = current_level_data.tooth_value_min
		var max_val = current_level_data.tooth_value_max
		tooth_values[tooth_name] = randi_range(min_val, max_val)
	
	print("🦷 Generated tooth values: ", tooth_values.size(), " teeth")

func assign_multiplier_teeth():
	tooth_multipliers.clear()
	
	var all_teeth = get_all_tooth_names()
	var num_multipliers = current_level_data.num_multiplier_teeth
	
	# Shuffle and pick random teeth for multipliers
	var available_teeth = all_teeth.duplicate()
	available_teeth.shuffle()
	
	for i in range(min(num_multipliers, available_teeth.size())):
		var tooth_name = available_teeth[i]
		var multiplier_value = game_config.default_multiplier_value
		
		# Use level-specific multipliers if available
		if i < current_level_data.multiplier_values.size():
			multiplier_value = current_level_data.multiplier_values[i]
		
		tooth_multipliers[tooth_name] = multiplier_value
	
	print("🦷 Assigned ", tooth_multipliers.size(), " multiplier teeth")

func get_all_tooth_names() -> Array[String]:
	var tooth_names: Array[String] = []
	
	if alligator_controller:
		for child in alligator_controller.get_children():
			if child is Area3D and "Tooth" in child.name:
				tooth_names.append(child.name)
	
	return tooth_names

func apply_tattoo_mapping(tattoo_mapping: Dictionary):
	tooth_tattoos = tattoo_mapping.duplicate()
	print("🦷 Applied tattoos to ", tooth_tattoos.size(), " teeth")
	
	# Update safe teeth list
	update_safe_teeth_list()

func update_safe_teeth_list():
	safe_teeth.clear()
	
	for tooth_name in tooth_tattoos.keys():
		var tattoos = tooth_tattoos[tooth_name]
		for tattoo in tattoos:
			if tattoo.affects_bite_selection():
				safe_teeth.append(tooth_name)
				break
	
	print("🛡️ Safe teeth: ", safe_teeth)

func get_safe_teeth() -> Array[String]:
	return safe_teeth.duplicate()

func is_tooth_safe(tooth_name: String) -> bool:
	return tooth_name in safe_teeth

func disable_tooth(tooth_name: String):
	if tooth_name not in disabled_teeth:
		disabled_teeth.append(tooth_name)
		print("🚫 Disabled tooth: ", tooth_name)

func enable_tooth(tooth_name: String):
	disabled_teeth.erase(tooth_name)
	print("✅ Enabled tooth: ", tooth_name)

func is_tooth_disabled(tooth_name: String) -> bool:
	return tooth_name in disabled_teeth

func get_tooth_world_position(tooth_name: String) -> Vector3:
	if alligator_controller:
		var tooth_node = alligator_controller.get_node_or_null(tooth_name)
		if tooth_node:
			return tooth_node.global_position
	return Vector3.ZERO

func _on_alligator_tooth_pressed(tooth_name: String):
	# Check if tooth is disabled
	if is_tooth_disabled(tooth_name):
		print("🚫 Tooth ", tooth_name, " is disabled this round")
		return
	
	var score = calculate_tooth_score(tooth_name)
	emit_signal("tooth_pressed", tooth_name, score)

func _on_alligator_tooth_bit():
	# The alligator handles bite detection, we just forward the signal
	var pressed_teeth = alligator_controller.pressed_teeth
	if pressed_teeth.size() > 0:
		var last_tooth = pressed_teeth[-1]
		emit_signal("bite_tooth_hit", last_tooth)

func calculate_tooth_score(tooth_name: String) -> int:
	var base_value = tooth_values.get(tooth_name, 10)
	var multiplier = tooth_multipliers.get(tooth_name, 1.0)
	
	# Apply tattoo effects
	if tooth_tattoos.has(tooth_name):
		var tattoo_result = apply_tattoo_effects(tooth_name, base_value, multiplier)
		base_value = tattoo_result.value
		multiplier = tattoo_result.multiplier
	
	return int(base_value * multiplier)

func apply_tattoo_effects(tooth_name: String, base_value: int, base_multiplier: float) -> Dictionary:
	var result = {
		"value": base_value,
		"multiplier": base_multiplier
	}
	
	if not tooth_tattoos.has(tooth_name):
		return result
	
	var tattoos = tooth_tattoos[tooth_name]
	var game_state = create_game_state_for_tattoos(tooth_name)
	
	for tattoo in tattoos:
		var effect = tattoo.apply_effect(tooth_name, result.value, result.multiplier, game_state)
		result.value = effect.value
		result.multiplier = effect.multiplier
		
		# Handle special effects and persistent effects here if needed
		for special_effect in effect.special_effects:
			print("✨ Tattoo Effect: ", special_effect)
	
	return result

func create_game_state_for_tattoos(tooth_name: String) -> Dictionary:
	var pressed_count = 0
	if alligator_controller:
		pressed_count = alligator_controller.pressed_teeth.size()
	
	return {
		"teeth_pressed_count": pressed_count + 1,
		"current_round": 1,  # Get from game manager
		"is_bite_tooth": false,  # Determine from alligator
		"round_score": 0,  # Get from game manager
		"total_score": 0   # Get from game manager
	}

func is_multiplier_tooth(tooth_name: String) -> bool:
	return tooth_multipliers.has(tooth_name) and tooth_multipliers[tooth_name] > 1.0

# Debug functions
func debug_print_tooth_state():
	if game_config and game_config.debug_mode:
		print("=== TOOTH DEBUG STATE ===")
		print("Values: ", tooth_values)
		print("Multipliers: ", tooth_multipliers)
		print("Disabled: ", disabled_teeth)
		print("Safe: ", safe_teeth)
		print("Tattoo mapping: ", tooth_tattoos.keys())
