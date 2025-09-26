extends CanvasLayer

signal shop_closed(teeth_tattoo_mapping, purchased_artifacts_list)
signal tooth_selected_for_artifact(slot_index)

var available_tattoos: Array[TattooData] = []
var available_artifacts: Array[ArtifactData] = []
var player_money: int = 0
var teeth_slots: Array = []  # Array of ToothSlot nodes
var purchased_artifacts: Array[ArtifactData] = []
var newly_purchased_artifacts: Array[ArtifactData] = []
var artifact_selection_mode = false
var current_artifact_for_selection: ArtifactData = null

@onready var money_label = $ShopContainer/MoneyDisplay/MoneyLabel
@onready var tattoo_slots = [$ShopContainer/TattooSection/TattooContainer/TattooSlot1,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot2,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot3,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot4,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot5]
@onready var artifact_slots = [$ShopContainer/ArtifactSection/ArtifactContainer/ArtifactSlot1,
							   $ShopContainer/ArtifactSection/ArtifactContainer/ArtifactSlot2,
							   $ShopContainer/ArtifactSection/ArtifactContainer/ArtifactSlot3]
var tooltip: Control = null
@onready var exit_button = $ExitButton
@onready var clear_tooth_button = $ShopContainer/ArtifactSection/ArtifactContainer/ClearToothButton
@onready var teeth_container = $TeethDrawer/TeethContainer
@onready var teeth_drawer = $TeethDrawer

var drawer_closed_pos: Vector2
var drawer_open_pos: Vector2
var is_drawer_open = false
var drawer_busy = false

func _ready():
	print("Checking for tooltip node...")
	tooltip = get_node_or_null("Tooltip")
	if tooltip:
		print("Tooltip found: ", tooltip.name)
	else:
		print("ERROR: Tooltip node not found!")
	exit_button.pressed.connect(_on_exit_pressed)
	clear_tooth_button.pressed.connect(_on_clear_tooth_pressed)
	
	var viewport_size = get_viewport().size
	drawer_closed_pos = Vector2(0, viewport_size.y + 50)  # Hidden below screen
	drawer_open_pos = Vector2(0, viewport_size.y * 0.4)   # 40% from top
	
	# Start with drawer closed
	teeth_drawer.position = drawer_closed_pos
	
	# Create physics boundaries
	create_drawer_walls()
	
	# Connect tattoo signals once
	for i in range(tattoo_slots.size()):
		tattoo_slots[i].tattoo_dragged.connect(_on_tattoo_dragged)
		tattoo_slots[i].drag_started.connect(_on_drag_started)
		tattoo_slots[i].drag_ended.connect(_on_drag_ended)
		tattoo_slots[i].show_tooltip.connect(_on_show_tooltip)
		tattoo_slots[i].hide_tooltip.connect(_on_hide_tooltip)
		print("Tooltip signal connections for slot ", i)
	for i in range(artifact_slots.size()):
		artifact_slots[i].artifact_purchased.connect(_on_artifact_purchased)
		artifact_slots[i].show_tooltip.connect(_on_show_tooltip)
		artifact_slots[i].hide_tooltip.connect(_on_hide_tooltip)
		print("Connected tooltip signals for artifact slot ", i)
	generate_tattoo_pool()
	generate_artifact_pool()
	setup_physics_teeth()

func open_shop(money: int):
	print("Shop.open_shop called with money: ", money)
	player_money = money
	
	# Clear newly purchased artifacts when opening shop
	newly_purchased_artifacts.clear()
	
	update_money_display()
	generate_shop_items()
	visible = true
	
	print("Shop visibility set to: ", visible)

func create_drawer_walls():
	# Remove any existing walls
	for child in teeth_drawer.get_children():
		if child.name.ends_with("Wall"):
			child.queue_free()
	
	var drawer_size = teeth_drawer.size
	var wall_thickness = 30
	
	var walls = [
		{"name": "LeftWall", "pos": Vector2(-wall_thickness/2, drawer_size.y/2), "size": Vector2(wall_thickness, drawer_size.y + wall_thickness)},
		{"name": "RightWall", "pos": Vector2(drawer_size.x + wall_thickness/2, drawer_size.y/2), "size": Vector2(wall_thickness, drawer_size.y + wall_thickness)},
		{"name": "TopWall", "pos": Vector2(drawer_size.x/2, -wall_thickness/2), "size": Vector2(drawer_size.x + wall_thickness, wall_thickness)},
		{"name": "BottomWall", "pos": Vector2(drawer_size.x/2, drawer_size.y + wall_thickness/2), "size": Vector2(drawer_size.x + wall_thickness, wall_thickness)}
	]
	
	for wall_data in walls:
		# Create RigidBody2D wall that's frozen (kinematic)
		var wall = RigidBody2D.new()
		wall.name = wall_data.name
		wall.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		wall.freeze = true  # Can't move, but can collide
		teeth_drawer.add_child(wall)
		
		# Create CollisionShape2D
		var collision = CollisionShape2D.new()
		wall.add_child(collision)
		
		# Create RectangleShape2D
		var shape = RectangleShape2D.new()
		shape.size = wall_data.size
		collision.shape = shape
		
		# Position the wall
		wall.position = wall_data.pos
		
		print("Created kinematic wall: ", wall_data.name)

func generate_tattoo_pool():
	# Automatically load all TattooData resources from the folder
	available_tattoos.clear()
	
	var tattoo_folder = "res://Scripts/Resources/Tattoos/"
	var dir = DirAccess.open(tattoo_folder)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# Only process .tres files
			if file_name.ends_with(".tres"):
				var full_path = tattoo_folder + file_name
				print("Attempting to load: ", full_path)
				
				var tattoo_data = load(full_path) as TattooData
				if tattoo_data:
					available_tattoos.append(tattoo_data)
					print("✅ Loaded tattoo: ", tattoo_data.name, " with texture: ", tattoo_data.icon_texture != null)
				else:
					print("❌ Failed to load tattoo at: ", full_path)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
		print("Total tattoos loaded: ", available_tattoos.size())
	else:
		print("❌ Could not open tattoo directory: ", tattoo_folder)

func generate_artifact_pool():
	# Load artifacts from resources folder instead of creating them programmatically
	available_artifacts.clear()
	
	var artifact_folder = "res://Scripts/Resources/Artifacts/"
	var dir = DirAccess.open(artifact_folder)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path = artifact_folder + file_name
				print("Attempting to load artifact: ", full_path)
				
				var artifact_data = load(full_path) as ArtifactData
				if artifact_data:
					available_artifacts.append(artifact_data)
					print("✅ Loaded artifact: ", artifact_data.name)
					print("  - Type: ", artifact_data.effect_type)
					print("  - Is Active: ", artifact_data.is_active_artifact)
					print("  - Uses: ", artifact_data.max_uses)
				else:
					print("❌ Failed to load artifact at: ", full_path)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
		print("Total artifacts loaded: ", available_artifacts.size())
	else:
		print("❌ Could not open artifact directory: ", artifact_folder)

func generate_shop_items():
	var shuffled_tattoos: Array[TattooData] = []
	shuffled_tattoos.assign(available_tattoos)
	shuffled_tattoos.shuffle()
	
	print("=== GENERATING SHOP ITEMS ===")
	print("tattoo_slots.size(): ", tattoo_slots.size())
	print("shuffled_tattoos.size(): ", shuffled_tattoos.size())
	
	for i in range(min(5, tattoo_slots.size())):
		print("Processing tattoo slot ", i)
		
		if i < shuffled_tattoos.size():
			print("Setting up slot ", i, " with tattoo: ", shuffled_tattoos[i].name)
			tattoo_slots[i].setup_tattoo(shuffled_tattoos[i])
			
			# Debug the slot properties
			print("Slot ", i, " mouse_filter: ", tattoo_slots[i].mouse_filter)
			print("Slot ", i, " size: ", tattoo_slots[i].size)
			print("Slot ", i, " global_position: ", tattoo_slots[i].global_position)
			print("Slot ", i, " visible: ", tattoo_slots[i].visible)
		else:
			print("No tattoo data for slot ", i)
	
	# Generate 3 random artifacts for the shop
	var shuffled_artifacts: Array[ArtifactData] = []
	shuffled_artifacts.assign(available_artifacts)
	shuffled_artifacts.shuffle()
	
	for i in range(min(3, artifact_slots.size())):
		if i < shuffled_artifacts.size():
			artifact_slots[i].setup_artifact(shuffled_artifacts[i])
			
			# Check if this artifact is already owned
			var is_owned = false
			for owned in purchased_artifacts:
				if owned.id == shuffled_artifacts[i].id:
					is_owned = true
					break
			
			if is_owned:
				artifact_slots[i].mark_as_purchased()
			else:
				artifact_slots[i].mark_as_available()

func _on_tattoo_applied_to_slot(slot_index: int, tattoo_data: TattooData):
	if player_money >= tattoo_data.cost:
		# Deduct money
		player_money -= tattoo_data.cost
		update_money_display()
		
		print("Applied ", tattoo_data.name, " to slot ", slot_index)
	else:
		print("Not enough money!")
		
		# Use the tooth's built-in removal function
		if slot_index >= 0 and slot_index < teeth_slots.size():
			var tooth_slot = teeth_slots[slot_index]
			
			# Remove the last applied tattoo (the one that just failed)
			if tooth_slot.applied_tattoos.size() > 0:
				tooth_slot.remove_tattoo_at_index(tooth_slot.applied_tattoos.size() - 1)
			else:
				print("No tattoos to remove from slot ", slot_index)
		else:
			print("Invalid slot index: ", slot_index)

func _on_artifact_purchased(artifact_data: ArtifactData, cost: int):
	print("Artifact purchase attempted: ", artifact_data.name, " for ", cost, " gold")
	
	if player_money >= cost:
		# Check if artifact is already owned (for evolution)
		var already_owned = false
		var existing_artifact = null
		
		for owned in purchased_artifacts:
			if owned.id == artifact_data.id:
				already_owned = true
				existing_artifact = owned
				break
		
		if already_owned and artifact_data.can_evolve:
			# Handle evolution
			player_money -= cost
			
			# Create evolved form
			if artifact_data.evolved_form:
				# Remove old version from both lists
				purchased_artifacts.erase(existing_artifact)
				if existing_artifact in newly_purchased_artifacts:
					newly_purchased_artifacts.erase(existing_artifact)
				
				# Add evolved version to both lists
				var evolved_copy = artifact_data.evolved_form.duplicate()
				evolved_copy.reset_uses()
				purchased_artifacts.append(evolved_copy)
				newly_purchased_artifacts.append(evolved_copy)
				
				print("🔮 Artifact evolved to: ", artifact_data.evolved_form.name)
			
		elif not already_owned:
			# Normal purchase
			player_money -= cost
			
			# Create a copy with reset uses
			var artifact_copy = artifact_data.duplicate()
			artifact_copy.reset_uses()
			purchased_artifacts.append(artifact_copy)
			newly_purchased_artifacts.append(artifact_copy)  # Add to newly purchased
			
			print("Artifact purchased successfully! New balance: ", player_money)
		else:
			print("Artifact already owned and cannot evolve!")
			return
		
		update_money_display()
		update_artifact_shop_display()
		
	else:
		print("Not enough money! Need: ", cost, " Have: ", player_money)

func create_active_artifact_ui():
	# This would create UI buttons for active artifacts
	# You'd call this when the shop closes or during gameplay
	for artifact in purchased_artifacts:
		if artifact.is_active_artifact and artifact.uses_remaining != 0:
			create_artifact_button(artifact)

func create_artifact_button(artifact: ArtifactData):
	# Create a button for using active artifacts
	# Implementation depends on your UI setup
	print("Creating button for active artifact: ", artifact.name)

func create_random_tooth_mapping():
	# Create mapping from shop slots to actual game teeth
	var game_tooth_names = ["Left", "MidLeft", "MidRight", "Right", 
						   "LeftD", "RightD",
						   "L1", "L2", "L3", "L4", "L5",
						   "R1", "R2", "R3", "R4", "R5"]
	
	var tooth_mapping = {}
	
	for i in range(teeth_slots.size()):
		var slot = teeth_slots[i]
		if slot.applied_tattoos.size() > 0:
			# Randomly assign this slot's tattoos to a game tooth
			var random_tooth = game_tooth_names[randi() % game_tooth_names.size()]
			tooth_mapping[random_tooth] = slot.applied_tattoos.duplicate()
			
			print("Slot ", i, " with ", slot.applied_tattoos.size(), " tattoos assigned to tooth: ", random_tooth)
	
	return tooth_mapping

func update_artifact_shop_display():
	# Update all artifact slots to show current ownership status
	for slot in artifact_slots:
		if slot.artifact_data:
			var is_owned = false
			var can_evolve = false
			
			for owned in purchased_artifacts:
				if owned.id == slot.artifact_data.id:
					is_owned = true
					break
			
			# Check if player can evolve this artifact
			if slot.artifact_data.can_evolve:
				can_evolve = slot.artifact_data.can_evolve_now(purchased_artifacts)
			
			if is_owned and not can_evolve:
				slot.mark_as_purchased()
			elif can_evolve:
				slot.mark_as_evolvable()  # You'd need to implement this
			else:
				slot.mark_as_available()

func update_money_display():
	money_label.text = "Money: " + str(player_money)

func _on_clear_tooth_pressed():
	# Allow player to clear a slot for money
	print("Clear tooth feature - select a slot to clear")
	# You could implement a selection mode here

func _on_exit_pressed():
	visible = false
	var final_mapping = create_random_tooth_mapping()
	
	# Pass only newly purchased artifacts, not all purchased artifacts
	print("Passing ", newly_purchased_artifacts.size(), " newly purchased artifacts to game")
	emit_signal("shop_closed", final_mapping, newly_purchased_artifacts.duplicate())

# Make sure this function exists and has 2 parameters:
func _on_drag_started(tattoo_data: TattooData):
	print("Drag started, opening drawer for: ", tattoo_data.name)
	force_hide_tooltips()  # Force hide tooltip when dragging starts
	if not is_drawer_open:
		open_drawer()

func _on_drag_ended():
	print("Drag ended, closing drawer")
	if is_drawer_open:
		close_drawer()

func _on_show_tooltip(item_name: String, description: String, position: Vector2):
	print("Show tooltip signal received: ", item_name)
	if tooltip:
		tooltip.show_tooltip(item_name, description, position)  # Call tooltip's show function
	else:
		print("Tooltip is null!")

func _on_hide_tooltip():
	print("Hide tooltip signal received")
	if tooltip:
		tooltip.hide_tooltip()  # Call tooltip's hide function

func _on_tattoo_dragged(tattoo_data: TattooData, source_control):
	print("Tattoo being dragged: ", tattoo_data.name)
	# This can stay for any additional drag feedback

func is_dragging_tattoo() -> bool:
	return false  # Simple placeholder for now

func close_drawer():
	if not is_drawer_open or drawer_busy:
		return
	
	print("Closing drawer...")
	drawer_busy = true
	
	# First return teeth to grid positions
	return_teeth_to_grid()
	
	# Wait for teeth to settle
	await get_tree().create_timer(1.0).timeout
	
	if not is_drawer_open:
		drawer_busy = false
		return
	
	# Then slide drawer down
	is_drawer_open = false
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_IN)
	
	tween.tween_property(teeth_drawer, "position", drawer_closed_pos, 0.4)
	
	await tween.finished
	drawer_busy = false

func scatter_teeth():
	print("Scattering teeth!")
	
	# Enable physics for all teeth
	for tooth in teeth_slots:
		tooth.enable_physics()
	
	# Calculate center of the drawer for scatter effect
	var drawer_center = Vector2(400, 144)  # Adjust based on your drawer size
	
	# Scatter each tooth with a slight delay
	for i in range(teeth_slots.size()):
		var tooth = teeth_slots[i]
		
		# Small delay for more organic effect
		await get_tree().create_timer(randf_range(0.0, 0.1)).timeout
		
		# Calculate direction from center
		var direction = (tooth.position - drawer_center).normalized()
		direction = direction.rotated(randf_range(-0.3, 0.3))  # Add randomness
		
		# Apply scatter force
		var force = direction * randf_range(150, 300)
		tooth.apply_central_impulse(force)
		
		# Add some spin
		tooth.angular_velocity = randf_range(-3, 3)

func force_hide_tooltips():
	if tooltip:
		tooltip.force_hide()

func setup_physics_teeth():
	print("setup_physics_teeth called")
	
	if not teeth_container:
		print("ERROR: teeth_container is null!")
		return
	
	# Clear any existing teeth
	for child in teeth_container.get_children():
		child.queue_free()
	
	teeth_slots.clear()
	
	# Base grid on drawer size with safe margins
	var drawer_size = teeth_drawer.size
	var grid_cols = 4
	var grid_rows = 4
	
	# Add more margin to keep teeth well inside walls
	var margin_x = 60  # Keep teeth well away from side walls
	var margin_y = 60  # Keep teeth well away from top/bottom walls
	
	var usable_width = drawer_size.x - (margin_x * 2)
	var usable_height = drawer_size.y - (margin_y * 2)
	
	var slot_width = usable_width / grid_cols
	var slot_height = usable_height / grid_rows
	
	# Start position with margins
	var start_x = margin_x
	var start_y = margin_y
	
	for i in range(16):
		var row = i / grid_cols
		var col = i % grid_cols
		
		# Calculate position with proper spacing
		var pos = Vector2(start_x + col * slot_width + slot_width/2, 
						 start_y + row * slot_height + slot_height/2)
		
		print("Tooth ", i, " positioned at: ", pos, " (drawer size: ", drawer_size, ")")
		
		# Create physics tooth
		var physics_tooth = preload("res://Scenes/physics_tooth_slot.tscn").instantiate()
		teeth_container.add_child(physics_tooth)
		
		# Setup with grid position
		physics_tooth.setup_slot(i, pos)
		physics_tooth.tattoo_applied.connect(_on_tattoo_applied_to_slot)
		
		teeth_slots.append(physics_tooth)
	
	print("Finished creating ", teeth_slots.size(), " physics teeth")

# Replace scatter_teeth with slam_teeth_to_front
func slam_teeth_to_front():
	# Safety check
	if not is_drawer_open or drawer_busy:
		return
	
	print("Slamming teeth to front!")
	
	# Check if teeth_slots is valid
	if teeth_slots.size() == 0:
		print("No teeth to slam!")
		return
	
	# Slam each tooth with a slight delay for wave effect
	for i in range(teeth_slots.size()):
		# Safety check for each tooth
		if i >= teeth_slots.size() or not is_instance_valid(teeth_slots[i]):
			continue
			
		var tooth = teeth_slots[i]
		
		# Check if drawer is still open
		if not is_drawer_open:
			break
		
		# Stagger the slamming for a wave effect
		await get_tree().create_timer(randf_range(0.0, 0.2)).timeout
		
		# Final safety check
		if is_instance_valid(tooth) and is_drawer_open:
			tooth.slam_to_front()

# Update return_teeth_to_grid
func return_teeth_to_grid():
	print("Returning teeth to grid...")
	
	# Recalculate grid positions (same logic as setup)
	var drawer_size = teeth_drawer.size
	var grid_cols = 4
	var grid_rows = 4
	
	var usable_width = drawer_size.x * 0.8
	var usable_height = drawer_size.y * 0.7
	
	var slot_width = usable_width / grid_cols
	var slot_height = usable_height / grid_rows
	
	var start_x = (drawer_size.x - usable_width) / 2
	var start_y = (drawer_size.y - usable_height) / 2
	
	# Return each tooth to its updated grid position
	for i in range(teeth_slots.size()):
		var tooth = teeth_slots[i]
		var row = i / grid_cols
		var col = i % grid_cols
		
		var target_pos = Vector2(start_x + col * slot_width + slot_width/2, 
								start_y + row * slot_height + slot_height/2)
		
		tooth.return_to_grid(target_pos)

func open_drawer():
	if is_drawer_open:
		return
	
	print("Opening drawer...")
	is_drawer_open = true
	drawer_busy = true
	
	# Nuclear option: Recreate all teeth fresh
	recreate_all_teeth()
	
	# Move drawer to open position
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(teeth_drawer, "position", drawer_open_pos, 0.6)
	
	# Enable physics while drawer is moving
	for tooth in teeth_slots:
		tooth.freeze = false
		tooth.gravity_scale = 0
	if is_drawer_open:
		slam_teeth_to_front()
	await tween.finished
	drawer_busy = false

func test_artifact_connection():
	print("Shop received artifact test call!")
	open_drawer()

func open_drawer_for_artifact_selection(artifact: ArtifactData):
	print("Opening drawer for artifact selection: ", artifact.name)
	
	artifact_selection_mode = true
	current_artifact_for_selection = artifact
	
	# Make shop visible during artifact selection
	visible = true
	
	show_artifact_selection_instructions(artifact)
	open_drawer()
	connect_teeth_for_artifact_selection()

func show_artifact_selection_instructions(artifact: ArtifactData):
	print("Select a tooth to use ", artifact.name, " on")
	
	match artifact.id:
		"tooth_modifier":
			print("Select a tooth with no tattoos")
		"safe_tooth_revealer":
			print("Click any tooth to reveal safe teeth")

func connect_teeth_for_artifact_selection():
	print("Connecting teeth for artifact selection...")
	
	# Connect each tooth for artifact selection
	for i in range(teeth_slots.size()):
		var tooth = teeth_slots[i]
		if tooth:
			# Connect to the drop area's input for clicking
			var drop_area = tooth.get_node_or_null("DropArea")
			if drop_area:
				# Disconnect any existing connections first
				if drop_area.is_connected("gui_input", _on_tooth_clicked_for_artifact_selection):
					drop_area.disconnect("gui_input", _on_tooth_clicked_for_artifact_selection)
				
				# Connect the new signal
				drop_area.gui_input.connect(_on_tooth_clicked_for_artifact_selection.bind(i))
				print("Connected tooth ", i, " for artifact selection")

func setup_tooth_for_artifact_click(tooth, slot_index: int):
	# Add a click handler to the tooth for artifact selection
	print("Setting up tooth ", slot_index, " for artifact clicks")
	print("Tooth type: ", tooth.get_class())
	
	if tooth:
		# Check if it's a RigidBody2D (physics tooth)
		if tooth is RigidBody2D and tooth.has_signal("input_event"):
			if not tooth.is_connected("input_event", _on_tooth_input_event_for_artifact):
				tooth.input_event.connect(_on_tooth_input_event_for_artifact.bind(slot_index))
				print("Connected RigidBody2D tooth ", slot_index, " input_event signal")
		
		# Check for ToothDropArea child (Control node)
		var drop_area = tooth.get_node_or_null("DropArea")
		if drop_area and drop_area.has_signal("gui_input"):
			if not drop_area.is_connected("gui_input", _on_tooth_drop_area_clicked_for_artifact):
				drop_area.gui_input.connect(_on_tooth_drop_area_clicked_for_artifact.bind(slot_index))
				print("Connected DropArea ", slot_index, " gui_input signal")
		
		# Fallback: try gui_input on the tooth itself
		elif tooth.has_signal("gui_input"):
			if not tooth.is_connected("gui_input", _on_tooth_gui_input_for_artifact):
				tooth.gui_input.connect(_on_tooth_gui_input_for_artifact.bind(slot_index))
				print("Connected tooth ", slot_index, " gui_input signal")
		else:
			print("WARNING: Tooth ", slot_index, " has no usable input signals")

func _on_tooth_drop_area_clicked_for_artifact(event: InputEvent, slot_index: int):
	print("Drop area clicked for artifact selection, slot: ", slot_index)
	print("Artifact selection mode: ", artifact_selection_mode)
	
	if not artifact_selection_mode:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Valid drop area click for slot ", slot_index)
		
		if is_valid_tooth_for_artifact(slot_index):
			print("Valid tooth selected: ", slot_index)
			emit_signal("tooth_selected_for_artifact", slot_index)
			exit_artifact_selection_mode()
		else:
			print("Invalid tooth for artifact")

func _on_tooth_gui_input_for_artifact(event: InputEvent, slot_index: int):
	print("GUI input for artifact selection, slot: ", slot_index)
	
	if not artifact_selection_mode:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_valid_tooth_for_artifact(slot_index):
			emit_signal("tooth_selected_for_artifact", slot_index)
			exit_artifact_selection_mode()

func _on_tooth_input_event_for_artifact(camera, event, position, normal, shape_idx, slot_index: int):
	if not artifact_selection_mode:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Physics tooth slot ", slot_index, " clicked for artifact")
		
		# Check if this tooth is valid for the current artifact
		if is_valid_tooth_for_artifact(slot_index):
			emit_signal("tooth_selected_for_artifact", slot_index)
			exit_artifact_selection_mode()
		else:
			print("Invalid tooth for artifact ", current_artifact_for_selection.name)

func _on_tooth_clicked_for_artifact(event: InputEvent, slot_index: int):
	if not artifact_selection_mode:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Tooth slot ", slot_index, " clicked for artifact")
		
		# Check if this tooth is valid for the current artifact
		if is_valid_tooth_for_artifact(slot_index):
			emit_signal("tooth_selected_for_artifact", slot_index)
			exit_artifact_selection_mode()
		else:
			print("Invalid tooth for artifact ", current_artifact_for_selection.name)

func _on_tooth_clicked_for_artifact_selection(event: InputEvent, slot_index: int):
	print("Tooth clicked for artifact selection - Slot: ", slot_index, " Mode: ", artifact_selection_mode)
	
	if not artifact_selection_mode:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Valid click for artifact selection on slot: ", slot_index)
		
		if is_valid_tooth_for_artifact(slot_index):
			print("Tooth is valid, emitting signal...")
			emit_signal("tooth_selected_for_artifact", slot_index)
			exit_artifact_selection_mode()
		else:
			print("Invalid tooth for artifact: ", current_artifact_for_selection.name if current_artifact_for_selection else "none")

func is_valid_tooth_for_artifact(slot_index: int) -> bool:
	if not current_artifact_for_selection:
		return false
	
	match current_artifact_for_selection.id:
		"tooth_modifier":
			# Tooth Eater can only be used on teeth with no tattoos
			if slot_index < teeth_slots.size():
				var tooth = teeth_slots[slot_index]
				return tooth.applied_tattoos.size() == 0
			else:
				return false
		"safe_tooth_revealer":
			# Oracular Spectacular can be used anywhere
			return true
		_:
			return true

func exit_artifact_selection_mode():
	print("Exiting artifact selection mode")
	artifact_selection_mode = false
	current_artifact_for_selection = null
	close_drawer()
	visible = false

func get_teeth_slots() -> Array:
	return teeth_slots

func recreate_all_teeth():
	print("Recreating all teeth...")
	
	# Store applied tattoos before destroying teeth
	var tattoo_data = []
	for i in range(teeth_slots.size()):
		if i < teeth_slots.size() and is_instance_valid(teeth_slots[i]):
			tattoo_data.append(teeth_slots[i].applied_tattoos.duplicate())
		else:
			tattoo_data.append([])
	
	# Destroy and recreate teeth
	setup_physics_teeth()
	
	# Get the GameManager to restore artifact effects
	var game_manager = get_node("/root/Node3D")  # Adjust path as needed
	if game_manager and game_manager.has_method("restore_artifact_effects_to_teeth"):
		game_manager.restore_artifact_effects_to_teeth()
	
	# Reapply tattoos safely
	for i in range(min(tattoo_data.size(), teeth_slots.size())):
		if i < teeth_slots.size() and is_instance_valid(teeth_slots[i]):
			for tattoo in tattoo_data[i]:
				teeth_slots[i].apply_tattoo(tattoo)

func _input(event):
	if not visible:
		return
	
	if event is InputEventMouseMotion:
		var mouse_y = event.position.y
		var viewport_height = get_viewport().size.y
		
		# Check if currently dragging
		var currently_dragging = _is_currently_dragging()
		
		# Open drawer if mouse is near bottom and not already open and not dragging
		if mouse_y > viewport_height * 0.97 and not is_drawer_open and not currently_dragging:
			print("Mouse proximity: Opening drawer")
			open_drawer()
		
		# Close drawer if mouse moves away from bottom and not dragging
		elif mouse_y < viewport_height * 0.6 and is_drawer_open and not currently_dragging:
			print("Mouse proximity: Closing drawer")
			close_drawer()
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		print("Testing tooltip manually...")
		if tooltip:
			var mouse_pos = get_viewport().get_mouse_position()
			tooltip.show_tooltip("Test Tattoo", "This is a test description", mouse_pos)
		else:
			print("Tooltip is null!")
	
	# Hide tooltip with 'H' key
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		print("Hiding tooltip manually...")
		if tooltip:
			tooltip.hide_tooltip()

func _is_currently_dragging() -> bool:
	# Check if any tattoo is currently being dragged
	for tattoo_slot in tattoo_slots:
		if tattoo_slot.is_dragging:
			return true
	return false
