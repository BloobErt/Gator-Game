extends Control

signal tattoo_dragged(tattoo_data, source_control)
signal drag_started(tattoo_data)
signal drag_ended()
signal show_tooltip(item_name, description, position)
signal hide_tooltip()

var tattoo_data: TattooData
var is_dragging = false
var is_mouse_inside = false

@onready var icon = $Icon
@onready var cost_label = $CostLabel

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	if size == Vector2.ZERO:
		custom_minimum_size = Vector2(120, 150)
		size = custom_minimum_size
	
	# Connect mouse signals
	if not is_connected("mouse_entered", _mouse_entered):
		mouse_entered.connect(_mouse_entered)
	
	if not is_connected("mouse_exited", _mouse_exited):
		mouse_exited.connect(_mouse_exited)

# ADD THIS FUNCTION
func setup_tattoo(data: TattooData):
	tattoo_data = data
	
	print("Setting up tattoo: ", tattoo_data.name)
	
	if icon and tattoo_data.icon_texture:
		icon.texture = tattoo_data.icon_texture
	
	if cost_label:
		cost_label.text = str(tattoo_data.cost) + " Gold"

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				emit_signal("tattoo_dragged", tattoo_data, self)
				emit_signal("drag_started", tattoo_data)
				emit_signal("hide_tooltip")
			else:
				if is_dragging:
					is_dragging = false
					emit_signal("drag_ended")
	
	elif event is InputEventMouseMotion and is_mouse_inside and tattoo_data:
		if not is_dragging:
			emit_signal("show_tooltip", tattoo_data.name, tattoo_data.description, 
					   global_position + event.position)

func _get_drag_data(position):
	if tattoo_data:
		print("🎯 DRAGGING: ", tattoo_data.name)
		
		emit_signal("drag_started", tattoo_data)
		emit_signal("hide_tooltip")
		
		var preview = Control.new()
		var preview_icon = TextureRect.new()
		preview_icon.texture = tattoo_data.icon_texture
		preview_icon.size = Vector2(50, 50)
		preview.add_child(preview_icon)
		
		set_drag_preview(preview)
		
		return {"type": "tattoo", "data": tattoo_data, "source": self}
	
	return null

func _mouse_entered():
	is_mouse_inside = true
	
	if tattoo_data and not is_dragging:
		var tooltip_pos = global_position + Vector2(size.x / 2, 0)
		emit_signal("show_tooltip", tattoo_data.name, tattoo_data.description, tooltip_pos)

func _mouse_exited():
	is_mouse_inside = false
	emit_signal("hide_tooltip")

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		if is_dragging:
			is_dragging = false
			emit_signal("drag_ended")
