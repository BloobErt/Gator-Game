extends Node3D

# Game state
var pressed_teeth = []
var bite_tooth_index = null
var tooth_to_bone_map = {} 
var tooth_value_labels = {}
var tooth_multiplier_indicators = {}
var mouth_open = false
var original_tooth_positions = {}

# Direct reference to the skeleton
@onready var skeleton = $Body/Skeleton3D
@onready var animation_player = $AnimationPlayer  # Add an AnimationPlayer node to your alligator


# Signals
signal tooth_pressed(tooth_name)
signal tooth_bit

func _ready():
	# Set up the tooth-to-bone mapping
	_setup_tooth_bone_mapping()
	
	# Randomly select a bite tooth
	_select_random_bite_tooth()
	
	# Connect animation signals
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
	
	# Open the mouth when the game starts
	open_mouth()
	
	#store's teeth original pos
	_store_original_tooth_positions()

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

func _store_original_tooth_positions():
	if not skeleton:
		return
	
	for tooth_name in tooth_to_bone_map.keys():
		var bone_name = tooth_to_bone_map[tooth_name]
		
		# Find the bone index
		var bone_idx = skeleton.find_bone(bone_name)
		if bone_idx == -1:
			bone_idx = skeleton.find_bone("Teeth/" + bone_name)
		
		if bone_idx != -1:
			# Store the original Y position
			var pose = skeleton.get_bone_pose(bone_idx)
			original_tooth_positions[bone_name] = pose.origin.y

func _select_random_bite_tooth():
	var tooth_areas = []
	
	for child in get_children():
		if child is Area3D and "Tooth" in child.name:
			tooth_areas.append(child)
	
	# Get safe teeth from GameManager
	var safe_teeth = get_safe_teeth()
	
	# Filter out safe teeth
	var valid_bite_teeth = []
	for tooth in tooth_areas:
		var tooth_name = tooth.name
		if not safe_teeth.has(tooth_name):
			valid_bite_teeth.append(tooth)
		else:
			print("Tooth ", tooth_name, " is protected by Safe tattoo")
	
	# Select from remaining teeth
	if valid_bite_teeth.size() > 0:
		var random_index = randi() % valid_bite_teeth.size()
		bite_tooth_index = valid_bite_teeth[random_index].name
		print("Selected bite tooth: ", bite_tooth_index)
	else:
		print("WARNING: All teeth are safe! Selecting random tooth anyway.")
		if tooth_areas.size() > 0:
			var random_index = randi() % tooth_areas.size()
			bite_tooth_index = tooth_areas[random_index].name

func get_safe_teeth() -> Array:
	var safe_teeth = []
	
	var game_manager = get_parent()
	if game_manager and game_manager.has_method("get_teeth_with_safe_tattoos"):
		safe_teeth = game_manager.get_teeth_with_safe_tattoos()
	
	return safe_teeth

func press_tooth(tooth_name):
	var node_name = String(tooth_name)
	
	if not has_node(node_name) or node_name in pressed_teeth:
		return false
	
	var tooth_node = get_node(node_name)
	pressed_teeth.append(node_name)
	
	var game_manager = get_node(".")
	var is_multiplier = false
	
	if game_manager and game_manager.has_method("is_multiplier_tooth"):
		is_multiplier = game_manager.is_multiplier_tooth(node_name)
	
	# Animate the tooth
	if node_name in tooth_to_bone_map:
		var bone_name = tooth_to_bone_map[node_name]
		_animate_tooth_bone(bone_name, is_multiplier, tooth_node)
	
	# Check if it's ANY bite tooth (main or additional)
	var is_bite_tooth = (node_name == bite_tooth_index)
	
	# Check additional bite teeth from GameManager
	if game_manager and game_manager.has_method("get_additional_bite_teeth"):
		var additional_bites = game_manager.get_additional_bite_teeth()
		if node_name in additional_bites:
			is_bite_tooth = true
			print("Hit additional bite tooth: ", node_name)
	
	if is_bite_tooth:
		_trigger_bite_animation()
		emit_signal("tooth_bit")
		return true
	else:
		emit_signal("tooth_pressed", node_name)
		return false

# Animate a tooth bone with a smooth tween and simultaneous particles
func _animate_tooth_bone(bone_name, is_multiplier = false, tooth_node = null):
	if not skeleton:
		return
	
	# Find the bone index
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		# Try with "Teeth/" prefix
		bone_idx = skeleton.find_bone("Teeth/" + bone_name)
	
	if bone_idx != -1:
		# Store the original pose
		var original_pose = skeleton.get_bone_pose(bone_idx)
		var original_y = original_pose.origin.y
		
		# Determine particle position first (before animation)
		var particle_position
		if tooth_node:
			# Check for a dedicated particle emission point
			var particle_point = tooth_node.get_node_or_null("ParticlePoint")
			if particle_point:
				particle_position = particle_point.global_position
			else:
				# Try collision shape
				var collision_shape = tooth_node.get_node_or_null("CollisionShape3D")
				if collision_shape:
					particle_position = collision_shape.global_position
				else:
					particle_position = tooth_node.global_position
		else:
			# Fallback to bone position
			particle_position = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx).origin
		
		# Emit particles immediately
		_emit_tooth_particles(particle_position, is_multiplier)
		
		# Create a tween
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.set_ease(Tween.EASE_OUT)
		
		# We'll use a custom property to track position
		# First, create a dummy object to tween
		var dummy_object = Node.new()
		dummy_object.set_meta("offset", 0.0)
		add_child(dummy_object)
		
		# A callable function to update the bone pose
		var update_bone = func():
			var offset = dummy_object.get_meta("offset")
			var new_pose = original_pose
			new_pose.origin.y = original_y - offset
			skeleton.set_bone_pose(bone_idx, new_pose)
		
		# Tween the offset property - press down and stay down
		tween.tween_method(func(offset): 
			dummy_object.set_meta("offset", offset)
			update_bone.call()
		, 0.0, 0.01, 0.3)
		
		# Clean up the dummy object when done
		tween.tween_callback(func(): dummy_object.queue_free()).set_delay(0.5)

# Updated particle emission function
@warning_ignore("shadowed_variable_base_class")
# Emit tooth particles at a position
# Emit tooth particles with optional multiplier effect
func _emit_tooth_particles(position, is_multiplier = false):
	# Select the appropriate particle scene
	var particle_path
	
	if is_multiplier:
		particle_path = "res://Particles/Multiplierparticles.tscn"
		# Fallback to regular particles if multiplier particles don't exist
		if not ResourceLoader.exists(particle_path):
			particle_path = "res://Particles/tooth_particles_base.tscn"
	else:
		particle_path = "res://Particles/tooth_particles_base.tscn"
	
	# Check if the particle scene exists
	if ResourceLoader.exists(particle_path):
		# Load and instance the particle scene
		var particles_scene = load(particle_path)
		var particles = particles_scene.instantiate()
		
		# Add to the scene and position
		add_child(particles)
		particles.global_position = position
		
		# Activate the particles
		if particles is GPUParticles3D:
			particles.emitting = true
			
			# Auto-remove after emission
			await get_tree().create_timer(particles.lifetime + 0.5).timeout
			if is_instance_valid(particles):
				particles.queue_free()

# Trigger the bite animation
func _trigger_bite_animation():
	
	# Check if we have an animation player
	if animation_player:
		# Check if the bite animation exists
		if animation_player.has_animation("Chomp"):
			animation_player.play("Chomp")
		mouth_open = false

func reopen_mouth_after_bite():
	print("Reopening mouth after bite survivor artifact triggered")
	
	# Wait a moment for the bite animation to finish
	await get_tree().create_timer(1.0).timeout
	
	# Then open the mouth again
	open_mouth()
	
	print("Mouth reopened - ready for more teeth!")

func open_mouth():
	if mouth_open:
		return  # Already open
	
	# Check if we have an animation player
	if not animation_player:
		# Try to find one
		animation_player = get_node_or_null("AnimationPlayer")
		
		# If still not found, create one
		if not animation_player:
			animation_player = AnimationPlayer.new()
			add_child(animation_player)
	
	# Check if we have the open animation
	if animation_player.has_animation("Open"):
		animation_player.play("Open")
	
	mouth_open = true

# Add this function to close the mouth
func close_mouth():
	if not mouth_open:
		return  # Already closed
	
	# Check if we have an animation player
	if animation_player:
		# Check if the close animation exists
		if animation_player.has_animation("Close"):
			animation_player.play("Close")
	
	mouth_open = false

# Reset teeth for a new round
func reset_teeth():
	# Close the mouth first
	close_mouth()
	
	# Store the bite tooth before resetting
	var previous_bite_tooth = bite_tooth_index
	
	# Reset all tooth bones to their original positions
	_reset_tooth_positions()
	
	# Clear pressed teeth array
	pressed_teeth = []
	
	# Select a new bite tooth
	_select_random_bite_tooth()
	
	# Wait a moment, then open the mouth again
	await get_tree().create_timer(0.8).timeout
	open_mouth()
	
	# Specifically reset the bite tooth
	if previous_bite_tooth and previous_bite_tooth in tooth_to_bone_map:
		var bite_bone_name = tooth_to_bone_map[previous_bite_tooth]
		_force_reset_tooth(bite_bone_name)

# reset tooth positions
func _reset_tooth_positions():
	if not skeleton:
		return
	
	for tooth_name in tooth_to_bone_map.keys():
		var bone_name = tooth_to_bone_map[tooth_name]
		
		var bone_idx = skeleton.find_bone(bone_name)
		if bone_idx == -1:
			bone_idx = skeleton.find_bone("Teeth/" + bone_name)
		
		if bone_idx != -1:
			var pose = skeleton.get_bone_pose(bone_idx)
			
			# Use the stored original Y position if available
			if bone_name in original_tooth_positions:
				pose.origin.y = original_tooth_positions[bone_name]
			else:
				pose.origin.y = 0  # Default if not stored
			
			skeleton.set_bone_pose(bone_idx, pose)

func _force_reset_tooth(bone_name):
	# Find the bone index
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		# Try with "Teeth/" prefix
		bone_idx = skeleton.find_bone("Teeth/" + bone_name)
	
	if bone_idx != -1:
		# Create a new pose with original Y
		var original_y = 0
		if bone_name in original_tooth_positions:
			original_y = original_tooth_positions[bone_name]
		
		var pose = skeleton.get_bone_pose(bone_idx)
		pose.origin.y = original_y
		
		# Apply the pose - do it multiple times to ensure it takes effect
		skeleton.set_bone_pose(bone_idx, pose)
		
		# Wait a frame and set again to ensure it's applied
		await get_tree().process_frame
		skeleton.set_bone_pose(bone_idx, pose)

# Add this function to handle animation completion
func _on_animation_finished(anim_name):
	if anim_name == "Chomp":
		# Bite animation finished, keep mouth closed
		mouth_open = false
	elif anim_name == "Open":
		# Mouth is now fully open
		mouth_open = true
	elif anim_name == "Close":
		# Mouth is now fully closed
		mouth_open = false

# Add this back to your AlligatorController.gd script
func update_tooth_visuals(values, multipliers):
	# Clear any existing visuals first
	clear_tooth_visuals()
	
	# For each tooth, update visual indicators
	for child in get_children():
		if child is Area3D and "Tooth" in child.name:
			var tooth_name = child.name
			
			# Make sure the collision is enabled
			var collision = child.get_node_or_null("CollisionShape3D")
			if collision:
				collision.disabled = false
			
			# Set up any visual indicators you want here
			# For example, you might want to add special materials to teeth with multipliers
			if multipliers.has(tooth_name) and multipliers[tooth_name] > 1:
				# Maybe add a special glow or effect
				pass

# Add this function to clear visuals
func clear_tooth_visuals():
	# Clear value labels
	for tooth_name in tooth_value_labels.keys():
		if tooth_value_labels[tooth_name] and is_instance_valid(tooth_value_labels[tooth_name]):
			tooth_value_labels[tooth_name].queue_free()
	tooth_value_labels.clear()
	
	# Clear multiplier indicators
	for tooth_name in tooth_multiplier_indicators.keys():
		if tooth_multiplier_indicators[tooth_name] and is_instance_valid(tooth_multiplier_indicators[tooth_name]):
			tooth_multiplier_indicators[tooth_name].queue_free()
	tooth_multiplier_indicators.clear()
