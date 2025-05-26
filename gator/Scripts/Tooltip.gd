extends Control

@onready var name_label = $Background/MarginContainer/ContentContainer/NameLabel
@onready var description_label = $Background/MarginContainer/ContentContainer/DescriptionLabel

var hide_timer: Timer
var is_following_mouse = false
var target_position = Vector2.ZERO

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # This is crucial!
	
	# Create hide timer
	hide_timer = Timer.new()
	hide_timer.wait_time = 0.1
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)
	add_child(hide_timer)

func _process(delta):
	# Smooth follow if we're tracking mouse
	if is_following_mouse and visible:
		var current_mouse = get_viewport().get_mouse_position()
		var desired_pos = current_mouse + Vector2(15, -10)
		
		# Keep on screen
		var viewport_size = get_viewport().size
		if desired_pos.x + size.x > viewport_size.x:
			desired_pos.x = current_mouse.x - size.x - 15
		if desired_pos.y < 0:
			desired_pos.y = 10
		if desired_pos.y + size.y > viewport_size.y:
			desired_pos.y = viewport_size.y - size.y - 10
		
		# Smooth interpolation
		position = position.lerp(desired_pos, delta * 10)

func show_tooltip(item_name: String, description: String, mouse_pos: Vector2):
	hide_timer.stop()
	
	name_label.text = item_name
	description_label.text = description
	
	anchor_left = 0
	anchor_top = 0
	anchor_right = 0
	anchor_bottom = 0
	
	# Add padding to the minimum size calculation
	var base_width = 150
	var base_height = 50
	var padding = Vector2(16, 12)  # 8px margin on each side, 6px top/bottom
	
	custom_minimum_size = Vector2(base_width, base_height) + padding
	size = Vector2.ZERO
	
	await get_tree().process_frame
	
	# Position the content container with margins
	var content = $Background/MarginContainer/ContentContainer  # or $Background/ContentContainer
	if content:
		content.position = Vector2(8, 6)  # Left and top margins
		content.size = size - Vector2(16, 12)  # Subtract both side margins
	
	position = mouse_pos + Vector2(15, -10)
	
	# Keep on screen logic...
	var viewport_size = get_viewport().size
	if position.x + size.x > viewport_size.x:
		position.x = mouse_pos.x - size.x - 15
	if position.y < 0:
		position.y = 10
	if position.y + size.y > viewport_size.y:
		position.y = viewport_size.y - size.y - 10
	
	visible = true
	is_following_mouse = true

func hide_tooltip():
	hide_timer.start()

func _on_hide_timer_timeout():
	visible = false
	is_following_mouse = false

func force_hide():
	hide_timer.stop()
	visible = false
	is_following_mouse = false
