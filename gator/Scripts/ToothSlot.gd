extends Control

var applied_tattoos: Array[TattooData] = []
var max_tattoos = 3

@onready var tooth_icon = $ToothIcon
@onready var tattoo_container = $TattooContainer
@onready var tooth_label = $ToothLabel

signal tattoo_applied(slot_index, tattoo_data)

var slot_index: int

func setup_slot(index: int):
	slot_index = index
	
	# Add null check and defer if needed
	if tooth_label:
		tooth_label.text = "Slot " + str(index + 1)
	else:
		# If the node isn't ready yet, defer the call
		call_deferred("_update_label", index)

func _update_label(index: int):
	if tooth_label:
		tooth_label.text = "Slot " + str(index + 1)
	else:
		push_error("ToothLabel node not found! Check the node structure.")

# Rest of the script remains the same...
func _can_drop_data(position, data):
	# Can accept tattoo drops if not at max capacity
	return data.has("type") and data.type == "tattoo" and applied_tattoos.size() < max_tattoos

func _drop_data(position, data):
	if data.type == "tattoo":
		var tattoo_data = data.data
		apply_tattoo(tattoo_data)
		emit_signal("tattoo_applied", slot_index, tattoo_data)

func apply_tattoo(tattoo_data: TattooData):
	if applied_tattoos.size() < max_tattoos:
		applied_tattoos.append(tattoo_data)
		
		# Create visual representation - small icon
		var tattoo_visual = TextureRect.new()
		tattoo_visual.texture = tattoo_data.icon_texture
		tattoo_visual.custom_minimum_size = Vector2(20, 20)
		tattoo_visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tattoo_container.add_child(tattoo_visual)
		
		update_display()

func remove_all_tattoos():
	applied_tattoos.clear()
	
	# Remove visual representations
	for child in tattoo_container.get_children():
		child.queue_free()
	
	update_display()

func update_display():
	# Visual feedback based on tattoo count
	var alpha = 0.7 + (applied_tattoos.size() * 0.1)  # Gets slightly more opaque with more tattoos
	modulate = Color(1, 1, 1, alpha)
	
	# Optional: change border color based on tattoo count
	if applied_tattoos.size() > 0:
		var background = get_node_or_null("Background")
		if background:
			background.add_theme_stylebox_override("panel", create_colored_style())

func create_colored_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
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
	
	return style
