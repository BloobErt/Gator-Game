extends Node

# Game state
var current_level = 1
var current_round = 1
var score = 0
var round_score = 0
var level_target_score = 100  # Increases with each level
var money = 0

# Teeth values
var teeth_values = {}
var teeth_multipliers = {}
var current_tooth_tattoos = {}
var disabled_teeth_next_round: Array = []
var global_point_multiplier: float = 1.0
var additional_bite_teeth: Array = []

var owned_artifacts: Array[ArtifactData] = []
var active_artifact_effects: Dictionary = {} # For persistent effects
var safe_teeth_revealed: Array = []
var modified_teeth: Dictionary = {} # For teeth with changed properties

# References
@onready var alligator = $Alligator
@onready var game_ui = $GameUI
@onready var round_transition = $RoundTransition
@onready var shop = $Shop
@onready var artifact_ui = $ArtifactUI

func _ready():
	# Connect signals from alligator
	alligator.tooth_pressed.connect(_on_tooth_pressed)
	alligator.tooth_bit.connect(_on_tooth_bit)
	 # Connect transition signal if it exists
	if round_transition:
		if not round_transition.is_connected("continue_pressed", _on_continue_to_shop):
			round_transition.continue_pressed.connect(_on_continue_to_shop)
	else:
		push_error("Round transition reference is missing!")
	# Start the first level
	start_level(current_level)
	update_ui()
	if shop:
		shop.shop_closed.connect(_on_shop_closed)
	else:
		push_error("Shop reference is null! Add the Shop scene to your main scene.")
	
	if artifact_ui:
		artifact_ui.artifact_used.connect(_on_artifact_used)
		artifact_ui.selection_overlay.tooth_selected.connect(_on_tooth_selected_for_artifact)
		artifact_ui.selection_overlay.selection_cancelled.connect(_on_artifact_selection_cancelled)

func start_level(level):
	
	# Reset score only at the beginning of a new level
	score = 0
	current_round = 1
	level_target_score = 100 * level
	
	# Start the first round
	start_new_round()

# Update start_new_round to handle persistent effects
func start_new_round():
	# Handle disabled teeth from previous round
	disabled_teeth_next_round.clear()
	
	# Only reset the round_score (not the total score)
	round_score = 0
	
	# Reset the alligator
	alligator.reset_teeth()
	
	# Generate teeth values based on level difficulty
	generate_teeth_values(current_level)
	
	# Assign multipliers to some teeth
	assign_teeth_multipliers()
	
	# Update tooth visuals
	alligator.update_tooth_visuals(teeth_values, teeth_multipliers)
	
	if artifact_ui:
		artifact_ui.setup_artifacts(owned_artifacts)
	
	# Update UI
	update_ui()

func get_additional_bite_teeth() -> Array:
	return additional_bite_teeth.duplicate()

func get_teeth_with_safe_tattoos() -> Array:
	var safe_teeth = []
	
	for tooth_name in current_tooth_tattoos.keys():
		var tattoos = current_tooth_tattoos[tooth_name]
		for tattoo in tattoos:
			if tattoo.affects_bite_selection():
				safe_teeth.append(tooth_name)
				break
	
	return safe_teeth

func _on_tooth_pressed(tooth_name):
	# Check if tooth is disabled
	if tooth_name in disabled_teeth_next_round:
		print("Tooth ", tooth_name, " is disabled this round!")
		return
	
	# Get base values (modified by artifacts if applicable)
	var base_value = teeth_values.get(tooth_name, 10)
	var base_multiplier = teeth_multipliers.get(tooth_name, 1.0)
	
	# Apply tooth modifications from artifacts
	if modified_teeth.has(tooth_name):
		var mod = modified_teeth[tooth_name]
		base_value = int(base_value * mod.value_multiplier)
		print("🔧 Tooth modified by artifact: ", base_value)
	
	print("=== TOOTH PRESSED: ", tooth_name, " ===")
	print("Base value: ", base_value)
	print("Base multiplier: ", base_multiplier)
	
	# Create game state for effects
	var game_state = {
		"teeth_pressed_count": alligator.pressed_teeth.size() + 1,
		"current_round": current_round,
		"is_bite_tooth": tooth_name == alligator.bite_tooth_index,
		"round_score": round_score,
		"total_score": score
	}
	
	var final_value = base_value
	var final_multiplier = base_multiplier
	var all_special_effects = []
	var all_persistent_effects = []
	
	# Apply tattoo effects first
	if current_tooth_tattoos.has(tooth_name):
		var tattoos = current_tooth_tattoos[tooth_name]
		print("Found ", tattoos.size(), " tattoos on this tooth")
		
		for tattoo in tattoos:
			var effect_result = tattoo.apply_effect(tooth_name, final_value, final_multiplier, game_state)
			
			if tattoo.effect_type == "high_value_no_growth":
				final_value = effect_result.value
				final_multiplier = 1.0
				break
			else:
				final_value = effect_result.value
				final_multiplier = effect_result.multiplier
			
			all_special_effects.append_array(effect_result.special_effects)
			all_persistent_effects.append_array(effect_result.persistent_effects)
	
	# Apply artifact effects
	var artifact_result = apply_artifact_effects_to_tooth(tooth_name, final_value, final_multiplier, game_state)
	final_value = artifact_result.value
	final_multiplier = artifact_result.multiplier
	all_special_effects.append_array(artifact_result.special_effects)
	all_persistent_effects.append_array(artifact_result.persistent_effects)
	
	# Apply global point multiplier
	var tooth_score = final_value * final_multiplier * global_point_multiplier
	
	print("Final calculation: ", final_value, " * ", final_multiplier, " * ", global_point_multiplier, " = ", tooth_score)
	
	# Show special effect messages
	for effect_msg in all_special_effects:
		print("🌟 EFFECT: ", effect_msg)
	
	# Handle persistent effects
	for persistent_effect in all_persistent_effects:
		apply_persistent_effect(persistent_effect)
	
	# Show score popup
	show_score_popup_at_tooth(tooth_name, tooth_score, final_multiplier > base_multiplier)
	
	# Add to round score
	round_score += tooth_score
	
	# Update UI
	update_ui()

func show_score_popup_at_tooth(tooth_name: String, score: float, has_multiplier: bool):
	var tooth_node = alligator.get_node(tooth_name)
	if tooth_node:
		var collision_shape = tooth_node.get_node_or_null("CollisionShape3D")
		var position_3d = collision_shape.global_position if collision_shape else tooth_node.global_position
		
		var camera = get_viewport().get_camera_3d()
		if camera:
			var screen_position = camera.unproject_position(position_3d)
			game_ui.show_score_popup(score, screen_position, has_multiplier)
		else:
			game_ui.show_score_popup(score, Vector2(get_viewport().size / 2), has_multiplier)

func apply_persistent_effect(effect: Dictionary):
	match effect.type:
		"disable_next_round":
			var tooth_name = effect.tooth_name
			if not tooth_name in disabled_teeth_next_round:
				disabled_teeth_next_round.append(tooth_name)
				print("🚫 Tooth ", tooth_name, " will be disabled next round")
		
		"global_multiplier":
			global_point_multiplier *= effect.multiplier
			print("🌟 Global point multiplier increased to ", global_point_multiplier)
		
		"add_bite_tooth":
			# Add another random bite tooth
			var available_teeth = get_available_teeth_for_bite()
			if available_teeth.size() > 0:
				var new_bite_tooth = available_teeth[randi() % available_teeth.size()]
				additional_bite_teeth.append(new_bite_tooth)
				print("💀 Added additional bite tooth: ", new_bite_tooth)

func get_available_teeth_for_bite() -> Array:
	var all_teeth = []
	for child in alligator.get_children():
		if child is Area3D and "Tooth" in child.name:
			all_teeth.append(child.name)
	
	# Remove teeth that are already bite teeth or have safe tattoos
	var safe_teeth = get_teeth_with_safe_tattoos()
	var available = []
	
	for tooth in all_teeth:
		if tooth != alligator.bite_tooth_index and not tooth in additional_bite_teeth and not tooth in safe_teeth:
			available.append(tooth)
	
	return available

# Add this to GameManager.gd
func is_multiplier_tooth(tooth_name):
	return teeth_multipliers.has(tooth_name) and teeth_multipliers[tooth_name] > 1

func _on_tooth_bit():
	var last_pressed = alligator.pressed_teeth[-1] if alligator.pressed_teeth.size() > 0 else ""
	var is_bite_tooth = (last_pressed == alligator.bite_tooth_index or last_pressed in additional_bite_teeth)
	
	if is_bite_tooth:
		print("💀 BIT! Tooth ", last_pressed, " was a bite tooth")
		
		# Check if artifacts allow continuing after bite
		var game_state = {
			"bite_tooth": last_pressed,
			"round_score": round_score
		}
		
		var can_continue = handle_bite_tooth_artifacts(game_state)
		
		if can_continue:
			print("✨ Artifact prevents bite ending the round!")
			# Apply penalty but don't end round
			var penalty = round(round_score * 0.05)
			round_score -= penalty
			update_ui()
		else:
			# Normal bite behavior
			var penalty = round(round_score * 0.05)
			round_score -= penalty
			end_round(true)

# Update the end_round function in GameManager.gd
func end_round(bite_triggered = false):
	# Add round score to total score
	score += round_score
	
	# Award money based on round performance
	var money_earned = round_score / 10  # Simple conversion
	money += money_earned
	
	
	# Store the result values for the transition screen
	var final_round_score = round_score
	
	# Update UI with the total score
	update_ui()
	
	# Show the round transition with more complete information
	if round_transition:
		round_transition.show_results(final_round_score, money_earned, score, level_target_score)
	else:
		push_error("Round transition reference is null! Check the path.")
		# Fallback - open shop directly
		if shop:
			shop.open_shop(money)
		else:
			_proceed_to_next_round()

func _proceed_to_next_round():
	# Check if we've reached the target score
	if score >= level_target_score:
		# Move to next level
		current_level += 1
		start_level(current_level)
	else:
		# Check if this was the last round
		if current_round >= 5:
			print("Game over! Final score: ", score)
			# You can implement a restart button or other game over logic
		else:
			# Move to next round
			current_round += 1
			start_new_round()

func generate_teeth_values(level):
	teeth_values = {}
	
	# Get all tooth areas
	var tooth_areas = []
	for child in alligator.get_children():
		if child is Area3D and "Tooth" in child.name:
			tooth_areas.append(child.name)
	
	# Assign random values based on level
	var min_value = 5 * level
	var max_value = 15 * level
	
	for tooth in tooth_areas:
		teeth_values[tooth] = randi() % (max_value - min_value + 1) + min_value

func assign_teeth_multipliers():
	teeth_multipliers = {}
	
	# Get all tooth areas
	var tooth_areas = []
	for child in alligator.get_children():
		if child is Area3D and "Tooth" in child.name:
			tooth_areas.append(child.name)
	
	# Determine how many multipliers to add based on level
	var num_multipliers = 1 + (current_level / 3)  # More multipliers in higher levels
	num_multipliers = min(num_multipliers, tooth_areas.size() / 2)  # Cap at half the teeth
	
	# Assign multipliers randomly
	var available_teeth = tooth_areas.duplicate()
	for i in range(num_multipliers):
		if available_teeth.size() > 0:
			var index = randi() % available_teeth.size()
			var tooth = available_teeth[index]
			teeth_multipliers[tooth] = 2.0  # 2x multiplier
			available_teeth.remove_at(index)

func add_artifact(artifact: ArtifactData):
	# Check for evolution
	if artifact.can_evolve_now(owned_artifacts):
		var evolved = artifact.evolve()
		owned_artifacts.append(evolved)
		print("🔮 Artifact evolved to: ", evolved.name)
	else:
		owned_artifacts.append(artifact)
		print("📦 Added artifact: ", artifact.name)
	
	# Apply any persistent effects
	apply_persistent_artifact_effects()
	
	# Update artifact UI
	if artifact_ui:
		artifact_ui.setup_artifacts(owned_artifacts)

func _on_artifact_used(artifact_id: String, target_tooth: String):
	print("Using artifact: ", artifact_id, " on target: ", target_tooth)
	
	var success = use_active_artifact(artifact_id, target_tooth)
	
	if success:
		# Update the artifact UI to reflect used charges
		if artifact_ui:
			artifact_ui.update_artifact_displays()
	
	# Always end selection mode
	if artifact_ui:
		artifact_ui.end_tooth_selection()

func _on_tooth_selected_for_artifact(tooth_name: String):
	if artifact_ui and artifact_ui.selection_overlay.current_artifact:
		var artifact = artifact_ui.selection_overlay.current_artifact
		_on_artifact_used(artifact.id, tooth_name)

# Handle cancelled artifact selection
func _on_artifact_selection_cancelled():
	if artifact_ui:
		artifact_ui.end_tooth_selection()

# Apply passive artifact effects to tooth presses
func apply_artifact_effects_to_tooth(tooth_name: String, base_value: int, base_multiplier: float, game_state: Dictionary) -> Dictionary:
	var result = {
		"value": base_value,
		"multiplier": base_multiplier,
		"special_effects": [],
		"persistent_effects": []
	}
	
	for artifact in owned_artifacts:
		if artifact.effect_type == "passive":
			var artifact_result = artifact.apply_passive_effect(tooth_name, result.value, result.multiplier, game_state)
			result.value = artifact_result.value
			result.multiplier = artifact_result.multiplier
			result.special_effects.append_array(artifact_result.special_effects)
			result.persistent_effects.append_array(artifact_result.persistent_effects)
	
	return result

# Handle bite tooth trigger effects
func handle_bite_tooth_artifacts(game_state: Dictionary) -> bool:
	var can_continue = false
	
	for artifact in owned_artifacts:
		if artifact.effect_type == "trigger":
			var trigger_result = artifact.apply_trigger_effect("bite_tooth_hit", game_state)
			
			if trigger_result.can_continue:
				can_continue = true
			
			for effect in trigger_result.special_effects:
				print("🎯 Artifact Trigger: ", effect)
	
	return can_continue

# Use an active artifact on a specific tooth
func use_active_artifact(artifact_id: String, target_tooth: String = "") -> bool:
	for artifact in owned_artifacts:
		if artifact.id == artifact_id and artifact.is_active_artifact:
			var game_state = {
				"tooth_tattoos": current_tooth_tattoos,
				"current_round": current_round,
				"teeth_pressed_count": alligator.pressed_teeth.size()
			}
			
			var result = artifact.apply_active_effect(target_tooth, game_state)
			
			if result.success:
				# Apply persistent effects
				for effect in result.persistent_effects:
					apply_artifact_persistent_effect(effect)
				
				# Show special effects
				for effect in result.special_effects:
					print("⚡ Active Artifact: ", effect)
				
				return true
			else:
				for effect in result.special_effects:
					print("❌ Artifact Failed: ", effect)
	
	return false

# Apply persistent effects from artifacts
func apply_artifact_persistent_effect(effect: Dictionary):
	match effect.type:
		"modify_tooth":
			var tooth_name = effect.tooth_name
			modified_teeth[tooth_name] = {
				"value_multiplier": effect.value_multiplier,
				"max_tattoos": effect.max_tattoos
			}
			print("🔧 Modified tooth ", tooth_name)
		
		"reveal_safe_teeth":
			reveal_safe_teeth(effect.count)
		
		"set_max_rounds":
			# This would modify game rules
			print("⏰ Max rounds set to: ", effect.value)

# Reveal safe teeth with visual indicators
func reveal_safe_teeth(count: int):
	var safe_teeth = get_teeth_with_safe_tattoos()
	safe_teeth_revealed = safe_teeth.slice(0, min(count, safe_teeth.size()))
	
	# Create visual indicators (you'd implement this based on your UI system)
	for tooth_name in safe_teeth_revealed:
		create_safe_tooth_indicator(tooth_name)
	
	print("👁️ Revealed safe teeth: ", safe_teeth_revealed)

# Create visual indicator above safe tooth (placeholder)
func create_safe_tooth_indicator(tooth_name: String):
	# This would create an arrow or icon above the tooth
	# Implementation depends on your 3D scene setup
	print("Creating safe indicator for: ", tooth_name)

# Apply persistent artifact effects at round start
func apply_persistent_artifact_effects():
	for artifact in owned_artifacts:
		if artifact.effect_type == "persistent":
			var game_state = {
				"current_round": current_round,
				"current_level": current_level
			}
			
			var result = artifact.apply_persistent_effect(game_state)
			
			for effect in result.special_effects:
				print("🔄 Persistent Effect: ", effect)
			
			for modification in result.game_modifications:
				apply_game_modification(modification)

# Apply game modifications from artifacts
func apply_game_modification(modification: Dictionary):
	match modification.type:
		"set_max_rounds":
			# You'd modify your round system here
			print("Game modification: Max rounds = ", modification.value)

func update_ui():
	
	if game_ui:
		# Show both the round score and total score
		game_ui.update_score(round_score)
		game_ui.update_total_score(score, level_target_score)
		game_ui.update_round(current_round, 5)
		game_ui.update_level(current_level)
		game_ui.update_goal(level_target_score)
		game_ui.update_money(money)
	else:
		push_error("Game UI reference is null! Check the path.")

func _on_continue_to_shop():
	# Don't start transition here - it already started on bite
	if shop:
		shop.open_shop(money)
	else:
		_proceed_to_next_round()

func _on_shop_closed(teeth_tattoo_mapping, newly_purchased_artifacts):
	# Store the new tattoo mapping
	current_tooth_tattoos = teeth_tattoo_mapping
	print("=== SHOP CLOSED DEBUG ===")
	print("Tattoo mapping received:")
	for tooth_name in current_tooth_tattoos.keys():
		print("Tooth ", tooth_name, " has ", current_tooth_tattoos[tooth_name].size(), " tattoos:")
		for i in range(current_tooth_tattoos[tooth_name].size()):
			var tattoo = current_tooth_tattoos[tooth_name][i]
			print("  - ", tattoo.name, " (ID: ", tattoo.id, ", Type: ", tattoo.effect_type, ")")
	
	# Add only newly purchased artifacts to the game
	print("Processing ", newly_purchased_artifacts.size(), " newly purchased artifacts...")
	for artifact in newly_purchased_artifacts:
		print("Adding new artifact: ", artifact.name, " (ID: ", artifact.id, ")")
		add_artifact(artifact)
	
	print("Total owned artifacts: ", owned_artifacts.size())
	for artifact in owned_artifacts:
		print("- ", artifact.name, " (Type: ", artifact.effect_type, ")")
	
	print("=== END SHOP DEBUG ===")
	
	
	# Continue to next round
	_proceed_to_next_round()
