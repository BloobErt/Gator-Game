extends Control

var tooth_name: String
var applied_tattoos: Array[TattooData] = []
var max_tattoos = 3

@onready var tooth_icon = $ToothIcon
@onready var tattoo_container = $TattooContainer
@onready var tooth_label = $ToothLabel

signal tattoo_applied(tooth_name, tattoo_data)

func setup_tooth(name: String):
	tooth_name = name
	tooth_label.text = name

func _can_drop_data(position, data):
	# Can accept tattoo drops if not at max capacity
	return data.has("type") and data.type == "tattoo" and applied_tattoos.size() < max_tattoos

func _drop_data(position, data):
	if data.type == "tattoo":
		var tattoo_data = data.data
		apply_tattoo(tattoo_data)
		emit_signal("tattoo_applied", tooth_name, tattoo_data)

func apply_tattoo(tattoo_data: TattooData):
	if applied_tattoos.size() < max_tattoos:
		applied_tattoos.append(tattoo_data)
		
		# Create visual representation
		var tattoo_visual = TextureRect.new()
		tattoo_visual.texture = tattoo_data.icon_texture
		tattoo_visual.custom_minimum_size = Vector2(20, 20)
		tattoo_container.add_child(tattoo_visual)
		
		update_display()

func remove_all_tattoos():
	applied_tattoos.clear()
	
	# Remove visual representations
	for child in tattoo_container.get_children():
		child.queue_free()
	
	update_display()

func update_display():
	# Update visual state based on tattoos
	modulate = Color.WHITE if applied_tattoos.size() == 0 else Color.LIGHT_BLUE
