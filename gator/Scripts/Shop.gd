extends CanvasLayer

signal shop_closed(teeth_tattoo_mapping, purchased_artifacts_list)
signal tooth_selected_for_artifact(slot_index)

# Use the ShopItemGenerator instead of loading directly
@onready var item_generator = $ShopItemGenerator

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
@onready var exit_button = $ShopUI/ExitButton
@onready var clear_tooth_button = $ShopUI/ShopContainer/ArtifactSection/ArtifactContainer/ClearToothButton
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
	exit_button = get_node_or_null("ExitButton")
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	else:
		print("WARNING: ExitButton not found!")
	
	clear_tooth_button = get_node_or_null("ShopContainer/ArtifactSection/ArtifactContainer/ClearToothButton")
	if clear_tooth_button:
		clear_tooth_button.pressed.connect(_on_clear_tooth_pressed)
	else:
		print("WARNING: ClearToothButton not found!")
	
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
	
	# Setup ShopItemGenerator instead of loading directly
	if item_generator:
		item_generator.setup(null)  # Pass shop config if you have one
	
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

func generate_shop_items():
	# Use ShopItemGenerator instead of loading directly
	if item_generator:
		available_tattoos = item_generator.generate_tattoo_selection()
		available_artifacts = item_generator.generate_artifact_selection()
	else:
		print("❌ No ShopItemGenerator found!")
		return
	
	print("=== GENERATING SHOP ITEMS ===")
	print("tattoo_slots.size(): ", tattoo_slots.size())
	print("available_tattoos.size(): ", available_tattoos.size())
	
	for i in range(min(5, tattoo_slots.size())):
		print("Processing tattoo slot ", i)
		
		if i < available_tattoos.size():
			print("Setting up slot ", i, " with tattoo: ", available_tattoos[i].name)
			tattoo_slots[i].setup_tattoo(available_tattoos[i])
		else:
			print("No tattoo data for slot ", i)
	
	# Generate 3 random artifacts for the shop
	for i in range(min(3, artifact_slots.size())):
		if i < available_artifacts.size():
			artifact_slots[i].setup_artifact(available_artifacts[i])
			
			# Check if this artifact is already owned
			var is_owned = false
			for owned in purchased_artifacts:
				if owned.id == available_artifacts[i].id:
					is_owned = true
					break
			
			if is_owned:
				artifact_slots[i].mark_as_purchased()
			else:
				artifact_slots[i].mark_as_available()

# [Continue with all the rest of the original Shop.gd functions...]
# Just keep everything else exactly the same!

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

# [Include ALL the rest of the original Shop.gd functions here - 
#  just replace the tattoo/artifact loading parts with ShopItemGenerator calls]

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

func recreate_all_teeth():
	print("Recreating all teeth...")
	setup_physics_teeth()
