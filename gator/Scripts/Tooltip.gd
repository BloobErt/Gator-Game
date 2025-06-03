extends Control

@onready var background = $Background
@onready var margin_container = $Background/MarginContainer
@onready var content_container = $Background/MarginContainer/ContentContainer
@onready var name_label = $Background/MarginContainer/ContentContainer/NameLabel
@onready var description_label = $Background/MarginContainer/ContentContainer/DescriptionLabel

var hide_timer: Timer
var is_following_mouse = false
var is_size_stable = false
var cached_size = Vector2.ZERO

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create hide timer
	hide_timer = Timer.new()
	hide_timer.wait_time = 0.1
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)
	add_child(hide_timer)
	
	# Set up the tooltip structure for proper auto-sizing
	setup_tooltip_structure()

func setup_tooltip_structure():
	# Reset all anchors and positions to use the container system properly
	anchor_left = 0
	anchor_top = 0
	anchor_right = 0
	anchor_bottom = 0
	
	# Make sure the background uses the full size of this control
	if background:
		background.anchor_left = 0
		background.anchor_top = 0
		background.anchor_right = 1
		background.anchor_bottom = 1
		background.offset_left = 0
		background.offset_top = 0
		background.offset_right = 0
		background.offset_bottom = 0
	
	# Ensure labels have proper text wrapping
	if name_label:
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	if description_label:
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _process(delta):
	# Only follow mouse if size is stable, we're supposed to be following, and we're already at the right position
	if is_following_mouse and visible and is_size_stable:
		var current_mouse = get_viewport().get_mouse_position()
		var desired_pos = calculate_tooltip_position(current_mouse)
		
		# Only start lerping if we're already very close to the target position
		var distance_to_target = position.distance_to(desired_pos)
		if distance_to_target < 5.0:  # Only start smooth movement when within 5 pixels
			position = position.lerp(desired_pos, delta * 20)
		else:
			# If we're far from target, snap immediately (this handles the initial positioning)
			position = desired_pos

func calculate_tooltip_position(mouse_pos: Vector2) -> Vector2:
	var desired_pos = mouse_pos + Vector2(15, -10)
	
	# Keep on screen using cached size to avoid recalculation
	var viewport_size = get_viewport().size
	var tooltip_size = cached_size
	
	if desired_pos.x + tooltip_size.x > viewport_size.x:
		desired_pos.x = mouse_pos.x - tooltip_size.x - 15
	if desired_pos.y < 0:
		desired_pos.y = 10
	if desired_pos.y + tooltip_size.y > viewport_size.y:
		desired_pos.y = viewport_size.y - tooltip_size.y - 10
	
	return desired_pos

func show_tooltip(item_name: String, description: String, mouse_pos: Vector2):
	hide_timer.stop()
	
	# Stop following mouse while we recalculate size
	is_following_mouse = false
	is_size_stable = false
	
	# Keep tooltip invisible during setup
	visible = false
	
	# Set the text content
	if name_label:
		name_label.text = item_name
	if description_label:
		description_label.text = description
	
	# Reset size to allow auto-sizing
	custom_minimum_size = Vector2.ZERO
	size = Vector2.ZERO
	
	# Wait for the text to be processed and containers to calculate their size
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Now get the calculated minimum size from the content
	var content_size = Vector2.ZERO
	if content_container:
		content_size = content_container.get_combined_minimum_size()
	
	# Add some padding for the margin container and background
	var total_padding = Vector2(20, 16)
	var final_size = content_size + total_padding
	
	# Set minimum size constraints
	final_size.x = max(final_size.x, 120)
	final_size.y = max(final_size.y, 40)
	
	# Apply the calculated size
	custom_minimum_size = final_size
	size = final_size
	cached_size = final_size
	
	# Wait one more frame for the size to actually apply
	await get_tree().process_frame
	
	# Calculate the final position
	var final_position = calculate_tooltip_position(mouse_pos)
	
	# Set position immediately without animation
	position = final_position
	
	# Mark size as stable and start following mouse
	is_size_stable = true
	is_following_mouse = true
	
	# Finally show the tooltip now that everything is calculated and positioned
	visible = true

func hide_tooltip():
	hide_timer.start()

func _on_hide_timer_timeout():
	visible = false
	is_following_mouse = false
	is_size_stable = false

func force_hide():
	hide_timer.stop()
	visible = false
	is_following_mouse = false
	is_size_stable = false
