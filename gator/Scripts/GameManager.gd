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

# Artifacts (special bonuses)
var active_artifacts = []

# References
@onready var alligator = $Alligator
@onready var game_ui = $GameUI
@onready var round_transition = $RoundTransition
@onready var shop = $Shop

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

func start_level(level):
	
	# Reset score only at the beginning of a new level
	score = 0
	current_round = 1
	level_target_score = 100 * level
	
	# Generate artifacts for this level
	active_artifacts = generate_artifacts_for_level(level)
	
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
	
	# Calculate base score for this tooth
	var base_value = teeth_values.get(tooth_name, 10)
	var base_multiplier = teeth_multipliers.get(tooth_name, 1.0)
	
	print("=== TOOTH PRESSED: ", tooth_name, " ===")
	print("Base value: ", base_value)
	print("Base multiplier: ", base_multiplier)
	
	# Create game state for tattoo effects
	var game_state = {
		"teeth_pressed_count": alligator.pressed_teeth.size() + 1, # +1 because this tooth isn't added to pressed_teeth yet
		"current_round": current_round,
		"is_bite_tooth": tooth_name == alligator.bite_tooth_index,
		"round_score": round_score,
		"total_score": score
	}
	
	var final_value = base_value
	var final_multiplier = base_multiplier
	var all_special_effects = []
	var all_persistent_effects = []
	
	# Apply tattoo effects if this tooth has tattoos
	if current_tooth_tattoos.has(tooth_name):
		var tattoos = current_tooth_tattoos[tooth_name]
		print("Found ", tattoos.size(), " tattoos on this tooth")
		
		for tattoo in tattoos:
			print("Applying tattoo: ", tattoo.name, " (Type: ", tattoo.effect_type, ")")
			
			var effect_result = tattoo.apply_effect(tooth_name, final_value, final_multiplier, game_state)
			
			# Handle special case: high_value_no_growth overrides everything
			if tattoo.effect_type == "high_value_no_growth":
				final_value = effect_result.value
				final_multiplier = 1.0 # No other multipliers apply
				print("  High value no growth: Set to ", final_value, " (no other effects apply)")
				break
			else:
				final_value = effect_result.value
				final_multiplier = effect_result.multiplier
			
			# Collect special effects and persistent effects
			all_special_effects.append_array(effect_result.special_effects)
			all_persistent_effects.append_array(effect_result.persistent_effects)
			
			print("  Value: ", base_value, " -> ", final_value)
			print("  Multiplier: ", base_multiplier, " -> ", final_multiplier)
	
	# Apply global point multiplier
	var tooth_score = final_value * final_multiplier * global_point_multiplier
	
	print("Final calculation: ", final_value, " * ", final_multiplier, " * ", global_point_multiplier, " = ", tooth_score)
	
	# Show special effect messages
	for effect_msg in all_special_effects:
		print("🌟 SPECIAL EFFECT: ", effect_msg)
	
	# Handle persistent effects
	for persistent_effect in all_persistent_effects:
		apply_persistent_effect(persistent_effect)
	
	# Show score popup
	show_score_popup_at_tooth(tooth_name, tooth_score, final_multiplier > base_multiplier)
	
	# Apply artifact effects
	tooth_score = apply_artifact_effects(tooth_score, alligator.pressed_teeth.size())
	
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
	# Check if the pressed tooth is any of the bite teeth
	var last_pressed = alligator.pressed_teeth[-1] if alligator.pressed_teeth.size() > 0 else ""
	
	var is_bite_tooth = (last_pressed == alligator.bite_tooth_index or last_pressed in additional_bite_teeth)
	
	if is_bite_tooth:
		print("💀 BIT! Tooth ", last_pressed, " was a bite tooth")
		# Apply penalty - lose 5% of round score
		var penalty = round(round_score * 0.05)
		round_score -= penalty
		
		# End the round with bite flag
		end_round(true)
	else:
		print("🤔 Bite triggered but last pressed tooth wasn't a bite tooth")

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

func generate_artifacts_for_level(level):
	# This generates random artifacts based on level
	var artifacts = []
	
	# Example artifacts - you can expand this with more types
	var possible_artifacts = [
		{
			"name": "Steady Hand",
			"description": "After pressing 3 teeth, multiply score by 1.2",
			"threshold": 3,
			"multiplier": 1.2
		},
		{
			"name": "Risk Taker",
			"description": "After pressing 5 teeth, multiply score by 1.5",
			"threshold": 5,
			"multiplier": 1.5
		},
		{
			"name": "Early Bird",
			"description": "First tooth pressed has 2x value",
			"threshold": 1,
			"multiplier": 2.0
		}
	]
	
	# Select random artifacts based on level
	var num_artifacts = 1 + (level / 2)  # More artifacts in higher levels
	for i in range(min(num_artifacts, possible_artifacts.size())):
		var index = randi() % possible_artifacts.size()
		artifacts.append(possible_artifacts[index])
		possible_artifacts.remove_at(index)
	
	return artifacts

func apply_artifact_effects(tooth_score, teeth_pressed):
	var modified_score = tooth_score
	
	for artifact in active_artifacts:
		if artifact.has("threshold") and teeth_pressed == artifact.threshold:
			modified_score *= artifact.get("multiplier", 1.0)
	
	return modified_score

func display_artifacts():
	# Later, you'll create UI elements for this
	# For now, just print to console
	print("Active Artifacts:")
	for artifact in active_artifacts:
		print("- ", artifact.name, ": ", artifact.description)

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
	# Instead of immediately proceeding, open the shop first
	if shop:
		shop.open_shop(money)
	else:
		# Fallback if shop isn't available
		_proceed_to_next_round()

func _on_shop_closed(teeth_tattoo_mapping, artifacts_list):
	# Store the new tattoo mapping
	current_tooth_tattoos = teeth_tattoo_mapping
	
	# Store purchased artifacts
	active_artifacts = artifacts_list
	
	print("Shop closed. Tattoo mapping received:")
	for tooth_name in current_tooth_tattoos.keys():
		print("Tooth ", tooth_name, " has ", current_tooth_tattoos[tooth_name].size(), " tattoos")
	
	print("Active artifacts: ", active_artifacts.size())
	for artifact in active_artifacts:
		print("- ", artifact.name)
	
	# Continue to next round
	_proceed_to_next_round()
