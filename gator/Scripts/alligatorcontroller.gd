extends Node3D

# Game state
var pressed_teeth = []
var bite_tooth_index = null
var tooth_to_bone_map = {} # Maps tooth Area3D names to skeleton bone names

# Direct reference to the skeleton
@onready var skeleton = $Body/Skeleton3D

# Signals
signal tooth_pressed(tooth_name)
signal tooth_bit

func _ready():
	# Verify we found the skeleton
	if skeleton:
		print("Found skeleton with ", skeleton.get_bone_count(), " bones")
		# Print all bones to help with debugging
		for i in range(skeleton.get_bone_count()):
			print("Bone ", i, ": ", skeleton.get_bone_name(i))
	else:
		push_error("Skeleton not found! Check the path: $Body/Skeleton3D")
	
	# Set up the tooth-to-bone mapping
	_setup_tooth_bone_mapping()
	
	# Randomly select a bite tooth
	_select_random_bite_tooth()

# Set up mapping between tooth areas and bone names
func _setup_tooth_bone_mapping():
	# Map front teeth
	tooth_to_bone_map["ToothFrontLeft"] = "Left"
	tooth_to_bone_map["ToothFrontMidLeft"] = "MidLeft"
	tooth_to_bone_map["ToothFrontMidRight"] = "MidRight"
	tooth_to_bone_map["ToothFrontRight"] = "Right"
	
	# Map diagonal teeth
	tooth_to_bone_map["ToothDiagonalLeft"] = "LeftD"
	tooth_to_bone_map["ToothDiagonalRight"] = "RightD"
	
	# Map side teeth (left)
	tooth_to_bone_map["ToothSideL1"] = "L1"
	tooth_to_bone_map["ToothSideL2"] = "L2"
	tooth_to_bone_map["ToothSideL3"] = "L3"
	tooth_to_bone_map["ToothSideL4"] = "L4"
	tooth_to_bone_map["ToothSideL5"] = "L5"
	
	# Map side teeth (right)
	tooth_to_bone_map["ToothSideR1"] = "R1"
	tooth_to_bone_map["ToothSideR2"] = "R2"
	tooth_to_bone_map["ToothSideR3"] = "R3"
	tooth_to_bone_map["ToothSideR4"] = "R4"
	tooth_to_bone_map["ToothSideR5"] = "R5"

# Select a random bite tooth
func _select_random_bite_tooth():
	var tooth_areas = []
	
	# Print all children of the Alligator node
	print("Children of Alligator node:")
	for child in get_children():
		print("- Child: ", child.name, " (", child.get_class(), ")")
		
		# Check if it's an Area3D with "Tooth" in the name
		if child is Area3D and "Tooth" in child.name:
			tooth_areas.append(child)
			print("  --> Added as tooth area")
	
	print("Found ", tooth_areas.size(), " tooth areas")
	
	if tooth_areas.size() > 0:
		var random_index = randi() % tooth_areas.size()
		bite_tooth_index = tooth_areas[random_index].name
		print("Selected bite tooth: ", bite_tooth_index)
	else:
		print("No tooth areas found!")

# Press a tooth by its name
func press_tooth(tooth_name):
	# Convert StringName to String if needed
	var node_name = String(tooth_name)
	
	# Check if we have this tooth node
	if not has_node(node_name):
		print("Tooth node not found: ", node_name)
		return false
	
	# Check if already pressed
	if node_name in pressed_teeth:
		print("Tooth already pressed: ", node_name)
		return false
	
	# Mark as pressed
	pressed_teeth.append(node_name)
	
	# Get the actual node
	var tooth_node = get_node(node_name)
	print("Successfully got tooth node: ", tooth_node.name)
	
	# Animate the corresponding bone
	if node_name in tooth_to_bone_map:
		var bone_name = tooth_to_bone_map[node_name]
		_animate_tooth_bone(bone_name)
	else:
		print("No bone mapping for tooth: ", node_name)
	
	print("Pressed tooth: ", node_name)
	
	# Check if it's the bite tooth
	if node_name == bite_tooth_index:
		print("CHOMP! That was the bite tooth!")
		_trigger_bite_animation()
		emit_signal("tooth_bit")
		return true
	else:
		emit_signal("tooth_pressed", node_name)
		return false

# Animate a tooth bone
func _animate_tooth_bone(bone_name):
	if not skeleton:
		print("No skeleton to animate!")
		return
	
	# Look for the bone in the Teeth node first
	var teeth_bone_path = "Teeth/" + bone_name
	var bone_idx = skeleton.find_bone(teeth_bone_path)
	
	# If not found with path, try direct name
	if bone_idx == -1:
		bone_idx = skeleton.find_bone(bone_name)
	
	if bone_idx != -1:
		# Found the bone, animate it
		var pose = skeleton.get_bone_pose(bone_idx)
		# Move it down slightly (adjust axis as needed for your model)
		pose.origin.y -= 0.01
		skeleton.set_bone_pose(bone_idx, pose)
		print("Animated bone: ", bone_name)
	else:
		print("Could not find bone: ", bone_name, " or ", teeth_bone_path)

# Trigger the bite animation
func _trigger_bite_animation():
	print("Bite animation triggered!")
	# We'll implement this with an AnimationPlayer later
