extends Node3D

# References
@onready var skeleton = $AlligatorModel/Skeleton3D
@onready var animation_player = $AnimationPlayer

# Teeth groups
var teeth_groups = {
	"Front": [],  # Will store indices of front teeth bones
	"Sides": [],  # Will store indices of side teeth bones
	"Diagonals": []  # Will store indices of diagonal teeth bones
}

# Game state
var pressed_teeth = []
var bite_tooth_index = -1

func _ready():
	# Find and categorize teeth bones
	_map_teeth_bones()
	
	# Create a bite animation if it doesn't exist
	_create_animations_if_needed()
	
	# Randomly select a bite tooth
	_select_bite_tooth()

# Maps bone names to their indices and categories
func _map_teeth_bones():
	for i in range(skeleton.get_bone_count()):
		var bone_name = skeleton.get_bone_name(i)
		
		# Check which group this bone belongs to
		if "Front" in bone_name:
			teeth_groups["Front"].append(i)
		elif "Sides" in bone_name:
			teeth_groups["Sides"].append(i)
		elif "Diagonals" in bone_name:
			teeth_groups["Diagonals"].append(i)
	
	print("Found teeth bones: ", teeth_groups)

# Function to create animations if they don't exist
func _create_animations_if_needed():
	# We'll implement this next
	pass

# Randomly select a tooth that will trigger the bite
func _select_bite_tooth():
	# Get all available teeth
	var all_teeth = []
	for group in teeth_groups.values():
		all_teeth.append_array(group)
	
	if all_teeth.size() > 0:
		# Randomly select one to be the bite tooth
		bite_tooth_index = all_teeth[randi() % all_teeth.size()]

# Call this when the player clicks on a tooth
func press_tooth(group_name, index_in_group):
	if not teeth_groups.has(group_name) or index_in_group >= teeth_groups[group_name].size():
		return
	
	var bone_index = teeth_groups[group_name][index_in_group]
	
	# Don't allow already pressed teeth
	if bone_index in pressed_teeth:
		return
	
	# Add to pressed teeth
	pressed_teeth.append(bone_index)
	
	# Animate the tooth being pressed
	_animate_press_tooth(bone_index)
	
	# Check if it's the bite tooth
	if bone_index == bite_tooth_index:
		# It's the bite tooth! Trigger bite animation
		animation_player.play("bite")
		
		# Emit signal for game logic
		emit_signal("tooth_bit")
	else:
		# Regular tooth - emit signal for scoring
		emit_signal("tooth_pressed", bone_index)

# Animates pressing a tooth down
func _animate_press_tooth(bone_index):
	# Get current transform
	var current_transform = skeleton.get_bone_pose(bone_index)
	
	# Create a slightly pressed down transform
	var pressed_transform = current_transform
	pressed_transform.origin.y -= 0.05 # Move down slightly
	
	# Apply the new transform
	skeleton.set_bone_pose(bone_index, pressed_transform)
