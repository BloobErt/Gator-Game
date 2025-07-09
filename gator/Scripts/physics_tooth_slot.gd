extends RigidBody2D

var applied_tattoos: Array[TattooData] = []
var max_tattoos = 3
var slot_index: int
var original_position: Vector2

@onready var tooth_icon = $ToothIcon
@onready var tooth_label = $ToothLabel
@onready var background = $Background
@onready var drop_area = $DropArea
@onready var tattoo_container = $TattooContainer  # VBoxContainer for tattoo visuals

signal tattoo_applied(slot_index, tattoo_data)

func _ready():
	# Physics setup
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	gravity_scale = 0
	linear_damp = 4.0
	angular_damp = 5.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	max_contacts_reported = 10
	contact_monitor = true
	
	# Connect drop area signals
	if drop_area:
		drop_area.tattoo_dropped.connect(_on_tattoo_dropped)

func setup_slot(index: int, grid_position: Vector2):
	slot_index = index
	original_position = grid_position
	position = grid_position
	
	if tooth_label:
		tooth_label.text = "Slot " + str(index + 1)
	
	# Setup drop area reference to parent
	if drop_area and drop_area.has_method("set_parent_tooth"):
		drop_area.set_parent_tooth(self)
	
	print("Setup tooth slot ", slot_index, " at position ", grid_position)

func _on_tattoo_dropped(tattoo_data: TattooData):
	apply_tattoo(tattoo_data)

func apply_tattoo(tattoo_data: TattooData):
	if applied_tattoos.size() < max_tattoos:
		applied_tattoos.append(tattoo_data)
		emit_signal("tattoo_applied", slot_index, tattoo_data)
		
		# Create visual representation in the tattoo container
		create_tattoo_visual(tattoo_data)
		
		update_display()
		print("✅ Tattoo applied! Tooth ", slot_index, " now has ", applied_tattoos.size(), " tattoos")

func create_tattoo_visual(tattoo_data: TattooData):
	if not tattoo_container or not is_instance_valid(tattoo_container):
		print("ERROR: TattooContainer not found or invalid!")
		return
	
	# Create a small tattoo icon similar to the original ToothSlot.gd
	var tattoo_visual = TextureRect.new()
	tattoo_visual.texture = tattoo_data.icon_texture
	tattoo_visual.custom_minimum_size = Vector2(20, 20)
	tattoo_visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tattoo_visual.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	# Add tooltip functionality (optional)
	tattoo_visual.tooltip_text = tattoo_data.name + ": " + tattoo_data.description
	
	tattoo_container.add_child(tattoo_visual)

func remove_all_tattoos():
	applied_tattoos.clear()
	
	# Remove visual representations with proper null checks
	if tattoo_container and is_instance_valid(tattoo_container):
		for child in tattoo_container.get_children():
			if is_instance_valid(child):
				child.queue_free()
	
	update_display()

func remove_tattoo_at_index(index: int):
	if index >= 0 and index < applied_tattoos.size():
		applied_tattoos.remove_at(index)
		
		# Remove corresponding visual with proper null checks
		if tattoo_container and is_instance_valid(tattoo_container):
			if index < tattoo_container.get_child_count():
				var child = tattoo_container.get_child(index)
				if is_instance_valid(child):
					child.queue_free()
		
		update_display()

func can_accept_tattoo() -> bool:
	# Get effective max tattoos (considering artifact modifications)
	var effective_max = get_effective_max_tattoos()
	var result = applied_tattoos.size() < effective_max
	
	print("🎯 CAN DROP CHECK on tooth ", slot_index)
	print("  Current tattoos: ", applied_tattoos.size(), "/", effective_max)
	print("  Result: ", result)
	
	return result

func get_effective_max_tattoos() -> int:
	# First check if this slot was directly modified by max_tattoos
	if max_tattoos != 3:  # 3 is the default
		print("  🔧 Using modified max_tattoos: ", max_tattoos)
		return max_tattoos
	
	# Then check the GameManager's modification dictionary as backup
	var game_manager = get_node("/root/Node3D")  # Adjust path as needed
	if game_manager and game_manager.has_method("get") and game_manager.modified_teeth:
		var tooth_key = "slot_" + str(slot_index)
		if game_manager.modified_teeth.has(tooth_key):
			var modification = game_manager.modified_teeth[tooth_key]
			if modification.has("max_tattoos"):
				print("  🔧 Using GameManager modified max_tattoos: ", modification.max_tattoos)
				return modification.max_tattoos
	
	# Return default
	print("  📝 Using default max_tattoos: ", max_tattoos)
	return max_tattoos

func update_display():
	# Visual feedback based on tattoo count (similar to original ToothSlot.gd)
	var alpha = 0.7 + (applied_tattoos.size() * 0.1)  # Gets slightly more opaque with more tattoos
	modulate = Color(1, 1, 1, alpha)
	
	# Update background color based on tattoo count
	match applied_tattoos.size():
		0:
			background.color = Color.LIGHT_GRAY
		1:
			background.color = Color.LIGHT_GREEN
		2:
			background.color = Color.YELLOW
		3:
			background.color = Color.LIGHT_CORAL
		_:
			background.color = Color.RED
	
	# Optional: Create colored border style (adapted from original)
	if applied_tattoos.size() > 0:
		create_colored_border()

func create_colored_border():
	# You can implement border styling here if your background supports it
	# This would depend on whether you're using a Panel, NinePatchRect, or StyleBoxFlat
	if background and background is Panel:
		var style = StyleBoxFlat.new()
		style.bg_color = background.color
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		
		# Color border based on tattoo count
		match applied_tattoos.size():
			1:
				style.border_color = Color.GREEN
			2:
				style.border_color = Color.YELLOW
			3:
				style.border_color = Color.RED
			_:
				style.border_color = Color.GRAY
		
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 5
		
		background.add_theme_stylebox_override("panel", style)

# Physics functions remain the same...
func slam_to_front():
	var forward_force = randf_range(-250, -150)
	var side_force = randf_range(-80, 80)
	var slam_force = Vector2(side_force, forward_force)
	apply_central_impulse(slam_force)
	angular_velocity = randf_range(-1.5, 1.5)

func return_to_grid(new_grid_position: Vector2 = Vector2.ZERO):
	var target_pos = new_grid_position if new_grid_position != Vector2.ZERO else original_position
	if new_grid_position != Vector2.ZERO:
		original_position = new_grid_position
	
	freeze = true
	gravity_scale = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, 0.6)
	tween.tween_property(self, "rotation", 0.0, 0.6)

func force_physics_reset():
	freeze = true
	position = original_position
	rotation = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, original_position))
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
