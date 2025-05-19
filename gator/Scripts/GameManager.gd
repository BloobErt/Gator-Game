extends Node

# Game state
var current_level = 1
var current_round = 1
var score = 0
var round_score = 0
var level_target_score = 100  # Increases with each level

# Teeth values
var teeth_values = {}
var teeth_multipliers = {}

# Artifacts (special bonuses)
var active_artifacts = []

# References
@onready var alligator = $Alligator

func _ready():
	# Connect signals from alligator
	alligator.tooth_pressed.connect(_on_tooth_pressed)
	alligator.tooth_bit.connect(_on_tooth_bit)
	
	# Start the first level
	start_level(current_level)

func start_level(level):
	print("Starting level ", level)
	score = 0
	current_round = 1
	level_target_score = 100 * level
	
	# Generate artifacts for this level
	active_artifacts = generate_artifacts_for_level(level)
	
	# Start the first round
	start_new_round()
	
	# Update UI
	update_ui()

func start_new_round():
	print("Starting round ", current_round, " of level ", current_level)
	round_score = 0
	
	# Reset the alligator (this now includes closing then opening the mouth)
	alligator.reset_teeth()
	
	# Generate teeth values based on level difficulty
	generate_teeth_values(current_level)
	
	# Assign multipliers to some teeth
	assign_teeth_multipliers()
	
	# Wait for mouth to open before updating visuals
	await get_tree().create_timer(1.0).timeout
	
	# Update tooth visuals
	alligator.update_tooth_visuals(teeth_values, teeth_multipliers)
	
	# Update UI
	update_ui()

func _on_tooth_pressed(tooth_name):
	# Calculate score for this tooth
	var tooth_value = teeth_values.get(tooth_name, 10)  # Default to 10 if not found
	var multiplier = teeth_multipliers.get(tooth_name, 1.0)
	var tooth_score = tooth_value * multiplier
	
	print("Tooth ", tooth_name, " pressed! Value: ", tooth_value, " x", multiplier)
	
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
	print("BITE! Round ended with penalty.")
	
	# Apply penalty - lose 5% of round score
	var penalty = round(round_score * 0.05)
	round_score -= penalty
	
	# End the round
	end_round()

func end_round():
	# Add round score to total score
	score += round_score
	
	print("Round ended. Round score: ", round_score, " Total score: ", score)
	
	# Check if we've reached the target score
	if score >= level_target_score:
		print("Level ", current_level, " completed!")
		# Move to next level
		current_level += 1
		start_level(current_level)
	else:
		# Check if this was the last round
		if current_round >= 5:
			print("Game over! Final score: ", score)
			# Handle game over
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
	
	print("Generated teeth values: ", teeth_values)

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
	
	print("Assigned multipliers: ", teeth_multipliers)

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
	
	print("Generated artifacts: ", artifacts)
	return artifacts

func apply_artifact_effects(tooth_score, teeth_pressed):
	var modified_score = tooth_score
	
	for artifact in active_artifacts:
		if artifact.has("threshold") and teeth_pressed == artifact.threshold:
			modified_score *= artifact.get("multiplier", 1.0)
			print("Applied artifact effect: ", artifact.name, " New score: ", modified_score)
	
	return modified_score

func display_artifacts():
	# Later, you'll create UI elements for this
	# For now, just print to console
	print("Active Artifacts:")
	for artifact in active_artifacts:
		print("- ", artifact.name, ": ", artifact.description)

func update_ui():
	# Update all UI elements with current game state
	# For now, just print to console
	print("Level: ", current_level, " Round: ", current_round, "/5")
	print("Round Score: ", round_score, " Total Score: ", score, "/", level_target_score)
	
	# Later, you can update actual UI elements
	# $ScoreLabel.text = "Score: " + str(score)
	# etc.
