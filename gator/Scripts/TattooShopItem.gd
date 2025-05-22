extends Control

signal tattoo_dragged(tattoo_data, source_control)

var tattoo_data: TattooData
var is_dragging = false

@onready var icon = $Icon
@onready var name_label = $NameLabel
@onready var cost_label = $CostLabel
@onready var description_label = $DescriptionLabel

func setup_tattoo(data: TattooData):
	tattoo_data = data
	
	if icon and tattoo_data.icon_texture:
		icon.texture = tattoo_data.icon_texture
	
	if name_label:
		name_label.text = tattoo_data.name
	
	if cost_label:
		cost_label.text = str(tattoo_data.cost) + " Gold"
	
	if description_label:
		description_label.text = tattoo_data.description

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start drag
				is_dragging = true
				emit_signal("tattoo_dragged", tattoo_data, self)
			else:
				# End drag
				is_dragging = false

func _can_drop_data(position, data):
	return false  # Shop items can't receive drops

func _get_drag_data(position):
	if tattoo_data:
		# Create a visual representation for dragging
		var preview = Control.new()
		var preview_icon = TextureRect.new()
		preview_icon.texture = tattoo_data.icon_texture
		preview.add_child(preview_icon)
		
		set_drag_preview(preview)
		
		return {"type": "tattoo", "data": tattoo_data, "source": self}
	
	return null
