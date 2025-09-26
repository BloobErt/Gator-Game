# ToothDrawerManager.gd
# Manages the physics teeth drawer system
extends Control

signal tooth_selected(slot_index: int)

var teeth_slots: Array = []
var is_drawer_open: bool = false
var drawer_busy: bool = false
var artifact_selection_mode: bool = false
var current_artifact_for_selection: ArtifactData = null

@onready var teeth_container = $TeethContainer
@onready var color_rect = $ColorRect

var drawer_closed_pos: Vector2
var drawer_open_pos: Vector2

func _ready():
	setup_drawer_positions()
	create_physics_boundaries()
	setup_physics_teeth()

func setup(config = null):
	print("✅ ToothDrawerManager initialized")

func setup_drawer_positions():
	var viewport_size = get_viewport().size
	drawer_closed_pos = Vector2(0, viewport_size.y + 50)  # Hidden below screen
	drawer_open_pos = Vector2(0, viewport_size.y * 0.4)   # 40% from top
	
	# Start with drawer closed
	position = drawer_closed_pos

func create_physics_boundaries():
	# Remove any existing walls
	for child in get_children():
		if child.name.ends_with("Wall"):
			child.queue_free()
	
	var drawer_size = size
	var wall_thickness = 30
	
	var walls = [
		{"name": "LeftWall", "pos": Vector2(-wall_thickness/2, drawer_size.y/2), "size": Vector2(wall_thickness, drawer_size.y + wall_thickness)},
		{"name": "RightWall", "pos": Vector2(drawer_size.x + wall_thickness/2, drawer_size.y/2), "size": Vector2(wall_thickness, drawer_size.y + wall_thickness)},
		{"name": "TopWall", "pos": Vector2(drawer_size.x/2, -wall_thickness/2), "size": Vector2(drawer_size.x + wall_thickness, wall_thickness)},
		{"name": "BottomWall", "pos": Vector2(drawer_size.x/2, drawer_size.y + wall_thickness/2), "size": Vector2(drawer_size.x + wall_thickness, wall_thickness)}
	]
	
	for wall_data in walls:
		var wall = RigidBody2D.new()
		wall.name = wall_data.name
		wall.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		wall.freeze = true
		add_child(wall)
		
		var collision = CollisionShape2D.new()
		wall.add_child(collision)
		
		var shape = RectangleShape2D.new()
		shape.size = wall_data.size
		collision.shape = shape
		
		wall.position = wall_data.pos
		print("Created kinematic wall: ", wall_data.name)

func setup_physics_teeth():
	print("setup_physics_teeth called")
	
	if not teeth_container:
		print("ERROR: teeth_container is null!")
		return
	
	# SAVE EXISTING TATTOO DATA BEFORE CLEARING
	var saved_tattoos = {}
	for i in range(teeth_slots.size()):
		if i < teeth_slots.size() and is_instance_valid(teeth_slots[i]):
			var tooth = teeth_slots[i]
			if tooth.applied_tattoos.size() > 0:
				saved_tattoos[i] = tooth.applied_tattoos.duplicate()
				print("💾 Saved ", tooth.applied_tattoos.size(), " tattoos from slot ", i)
	
	# Clear any existing teeth
	for child in teeth_container.get_children():
		child.queue_free()
	
	teeth_slots.clear()
	
	# Wait for cleanup
	await get_tree().process_frame
	
	# Base grid on drawer size with safe margins
	var drawer_size = size
	var grid_cols = 4
	var grid_rows = 4
	
	var margin_x = 60
	var margin_y = 60
	
	var usable_width = drawer_size.x - (margin_x * 2)
	var usable_height = drawer_size.y - (margin_y * 2)
	
	var slot_width = usable_width / grid_cols
	var slot_height = usable_height / grid_rows
	
	var start_x = margin_x
	var start_y = margin_y
	
	for i in range(16):
		var row = i / grid_cols
		var col = i % grid_cols
		
		var pos = Vector2(start_x + col * slot_width + slot_width/2, 
						 start_y + row * slot_height + slot_height/2)
		
		print("Tooth ", i, " positioned at: ", pos, " (drawer size: ", drawer_size, ")")
		
		var physics_tooth = preload("res://Scenes/physics_tooth_slot.tscn").instantiate()
		teeth_container.add_child(physics_tooth)
		
		physics_tooth.setup_slot(i, pos)
		physics_tooth.tattoo_applied.connect(_on_tattoo_applied_to_slot)
		
		# Connect for artifact selection
		if physics_tooth.has_signal("gui_input"):
			physics_tooth.gui_input.connect(_on_tooth_clicked_for_artifact.bind(i))
		
		teeth_slots.append(physics_tooth)
		
		# RESTORE SAVED TATTOOS
		if saved_tattoos.has(i):
			var saved_tattoo_list = saved_tattoos[i]
			for tattoo_data in saved_tattoo_list:
				physics_tooth.applied_tattoos.append(tattoo_data)
				physics_tooth.create_tattoo_visual(tattoo_data)
			physics_tooth.update_display()
			print("🔄 Restored ", saved_tattoo_list.size(), " tattoos to slot ", i)
	
	print("Finished creating ", teeth_slots.size(), " physics teeth")
	if saved_tattoos.size() > 0:
		print("✅ Restored tattoos to ", saved_tattoos.size(), " slots")

# === DRAWER CONTROL ===

func open_drawer():
	if is_drawer_open or drawer_busy:
		return
	
	print("Opening drawer...")
	is_drawer_open = true
	drawer_busy = true
	
	# RECREATE ALL TEETH - this fixes the positioning issues
	print("🔄 Recreating teeth for fresh drawer opening")
	setup_physics_teeth()
	
	# BRING DRAWER TO FRONT
	move_to_front()
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(self, "position", drawer_open_pos, 0.6)
	
	# Enable physics and slam teeth (now with fresh teeth)
	for tooth in teeth_slots:
		tooth.freeze = false
		tooth.gravity_scale = 0
	
	slam_teeth_to_front()
	await tween.finished
	drawer_busy = false

func close_drawer():
	if not is_drawer_open or drawer_busy:
		return
	
	print("Closing drawer...")
	drawer_busy = true
	
	# Since we recreate teeth on open, we don't need to carefully return them to grid
	# Just slide the drawer down
	is_drawer_open = false
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_IN)
	
	tween.tween_property(self, "position", drawer_closed_pos, 0.4)
	await tween.finished
	drawer_busy = false
	print("✅ Drawer closed")

func slam_teeth_to_front():
	if not is_drawer_open or drawer_busy:
		return
	
	print("Slamming teeth to front!")
	
	for i in range(teeth_slots.size()):
		if i >= teeth_slots.size() or not is_instance_valid(teeth_slots[i]):
			continue
			
		var tooth = teeth_slots[i]
		if not is_drawer_open:
			break
		
		await get_tree().create_timer(randf_range(0.0, 0.2)).timeout
		
		if is_instance_valid(tooth) and is_drawer_open:
			tooth.slam_to_front()

func return_teeth_to_grid():
	print("Returning teeth to grid...")
	
	# Force all teeth to freeze and reset physics
	for tooth in teeth_slots:
		if is_instance_valid(tooth):
			tooth.freeze = true
			tooth.linear_velocity = Vector2.ZERO
			tooth.angular_velocity = 0.0
			tooth.rotation = 0.0
	
	# Wait a frame for physics to settle
	await get_tree().process_frame
	
	# Calculate proper grid positions (same as setup)
	var drawer_size = size
	var grid_cols = 4
	var grid_rows = 4
	
	var margin_x = 60
	var margin_y = 60
	
	var usable_width = drawer_size.x - (margin_x * 2)
	var usable_height = drawer_size.y - (margin_y * 2)
	
	var slot_width = usable_width / grid_cols
	var slot_height = usable_height / grid_rows
	
	var start_x = margin_x
	var start_y = margin_y
	
	# Reset each tooth to its original grid position
	for i in range(teeth_slots.size()):
		if i >= teeth_slots.size() or not is_instance_valid(teeth_slots[i]):
			continue
			
		var tooth = teeth_slots[i]
		var row = i / grid_cols
		var col = i % grid_cols
		
		var target_pos = Vector2(start_x + col * slot_width + slot_width/2, 
								start_y + row * slot_height + slot_height/2)
		
		# Force immediate position reset
		tooth.position = target_pos
		tooth.rotation = 0.0
		tooth.original_position = target_pos
		
		# Use the tooth's own method for smooth return
		tooth.return_to_grid(target_pos)
	
	print("✅ All teeth returned to grid positions")

# === ARTIFACT SELECTION ===

func open_for_artifact_selection(artifact: ArtifactData):
	artifact_selection_mode = true
	current_artifact_for_selection = artifact
	
	show_artifact_selection_instructions(artifact)
	open_drawer()

func show_artifact_selection_instructions(artifact: ArtifactData):
	print("Select a tooth to use ", artifact.name, " on")
	
	match artifact.id:
		"tooth_modifier":
			print("Select a tooth with no tattoos")
		"safe_tooth_revealer":
			print("Click any tooth to reveal safe teeth")

func _on_tooth_clicked_for_artifact(event: InputEvent, slot_index: int):
	if not artifact_selection_mode:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Tooth slot ", slot_index, " clicked for artifact")
		
		if is_valid_tooth_for_artifact(slot_index):
			emit_signal("tooth_selected", slot_index)
			exit_artifact_selection_mode()
		else:
			print("Invalid tooth for artifact ", current_artifact_for_selection.name if current_artifact_for_selection else "none")

func is_valid_tooth_for_artifact(slot_index: int) -> bool:
	if not current_artifact_for_selection:
		return false
	
	match current_artifact_for_selection.id:
		"tooth_modifier":
			if slot_index < teeth_slots.size():
				var tooth = teeth_slots[slot_index]
				return tooth.applied_tattoos.size() == 0
			else:
				return false
		"safe_tooth_revealer":
			return true
		_:
			return true

func exit_artifact_selection_mode():
	print("Exiting artifact selection mode")
	artifact_selection_mode = false
	current_artifact_for_selection = null
	close_drawer()

# === EVENT HANDLERS ===

func _on_tattoo_applied_to_slot(slot_index: int, tattoo_data: TattooData):
	print("Tattoo applied to slot ", slot_index, ": ", tattoo_data.name)

# === UTILITY ===

func get_teeth_slots() -> Array:
	return teeth_slots

func get_teeth_tattoo_mapping() -> Dictionary:
	var mapping = {}
	var game_tooth_names = ["ToothFrontLeft", "ToothFrontMidLeft", "ToothFrontMidRight", "ToothFrontRight", 
						   "ToothDiagonalLeft", "ToothDiagonalRight",
						   "ToothSideL1", "ToothSideL2", "ToothSideL3", "ToothSideL4", "ToothSideL5",
						   "ToothSideR1", "ToothSideR2", "ToothSideR3", "ToothSideR4", "ToothSideR5"]
	
	var used_tooth_names = []
	
	for i in range(teeth_slots.size()):
		var slot = teeth_slots[i]
		if slot.applied_tattoos.size() > 0:
			# Find an unused game tooth name
			var available_names = []
			for tooth_name in game_tooth_names:
				if not used_tooth_names.has(tooth_name):
					available_names.append(tooth_name)
			
			if available_names.size() > 0:
				var selected_tooth = available_names[randi() % available_names.size()]
				used_tooth_names.append(selected_tooth)
				mapping[selected_tooth] = slot.applied_tattoos.duplicate()
				print("Slot ", i, " with ", slot.applied_tattoos.size(), " tattoos assigned to tooth: ", selected_tooth)
			else:
				print("⚠️ No more available tooth names for slot ", i)
	
	print("Final mapping: ", mapping.size(), " teeth with tattoos")
	return mapping

# === DEBUG ===

func debug_teeth_state():
	print("=== TOOTH DRAWER DEBUG ===")
	print("Drawer open: ", is_drawer_open)
	print("Drawer busy: ", drawer_busy)
	print("Teeth count: ", teeth_slots.size())
	
	for i in range(teeth_slots.size()):
		var tooth = teeth_slots[i]
		print("  Tooth ", i, ": ", tooth.applied_tattoos.size(), " tattoos")

func recreate_all_teeth():
	print("Recreating all teeth...")
	setup_physics_teeth()

func _input(event):
	# Close drawer if clicking outside when it's open
	if is_drawer_open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if the click is outside the drawer area
		var mouse_pos = get_local_mouse_position()
		var drawer_rect = Rect2(Vector2.ZERO, size)
		
		if not drawer_rect.has_point(mouse_pos):
			print("🎯 Clicked outside drawer - closing")
			close_drawer()
