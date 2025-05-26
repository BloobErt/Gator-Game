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

func start_new_round():
	
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
	
	# Update UI - this will show the reset round_score
	update_ui()


func _on_tooth_pressed(tooth_name):
	# Calculate score for this tooth
	var tooth_value = teeth_values.get(tooth_name, 10)
	var multiplier = teeth_multipliers.get(tooth_name, 1.0)
	
	# Apply tattoo effects if this tooth has tattoos
	if current_tooth_tattoos.has(tooth_name):
		var tattoos = current_tooth_tattoos[tooth_name]
		for tattoo in tattoos:
			if tattoo.id == "mult_2x" or tattoo.id == "mult_3x" or tattoo.id == "mult_4x":
				multiplier *= tattoo.multiplier
			elif tattoo.id == "bonus_10" or tattoo.id == "bonus_20":
				var bonus = int(tattoo.id.split("_")[1])
				tooth_value += bonus
			elif tattoo.id == "lucky":
				if randf() < 0.1:  # 10% chance
					multiplier *= 5.0
		
	
	var tooth_score = tooth_value * multiplier
	
	
	# Previous round score
	var prev_round_score = round_score
	
	# Get the tooth node and its collision shape
	var tooth_node = alligator.get_node(tooth_name)
	if tooth_node:
		# Try to get the collision shape position
		var collision_shape = tooth_node.get_node_or_null("CollisionShape3D")
		var position_3d
		
		if collision_shape:
			position_3d = collision_shape.global_position
		else:
			position_3d = tooth_node.global_position
		
		# Convert 3D position to 2D screen position
		var camera = get_viewport().get_camera_3d()
		
		# Make sure we have a valid camera
		if camera:
			var screen_position = camera.unproject_position(position_3d)
			
			# Show the score popup at the converted screen position
			game_ui.show_score_popup(tooth_score, screen_position, multiplier > 1)
		else:
			# Fallback if camera can't be found
			game_ui.show_score_popup(tooth_score, Vector2(get_viewport().size / 2), multiplier > 1)
	else:
		# Fallback if tooth node can't be found
		game_ui.show_score_popup(tooth_score, Vector2(get_viewport().size / 2), multiplier > 1)
	
	# Apply artifact effects
	tooth_score = apply_artifact_effects(tooth_score, alligator.pressed_teeth.size())
	
	# Add to round score
	round_score += tooth_score
	
	
	# Update UI
	update_ui()

# Add this to GameManager.gd
func is_multiplier_tooth(tooth_name):
	return teeth_multipliers.has(tooth_name) and teeth_multipliers[tooth_name] > 1

func _on_tooth_bit():
	
	# Apply penalty - lose 5% of round score
	var penalty = round(round_score * 0.05)
	round_score -= penalty
	
	# End the round with bite flag
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
