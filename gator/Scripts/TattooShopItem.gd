extends Control

signal tattoo_dragged(tattoo_data, source_control)
signal drag_started(tattoo_data)
signal drag_ended()
signal show_tooltip(item_name, description, position)
signal hide_tooltip()

var tattoo_data: TattooData
var is_dragging = false
var is_mouse_inside = false
var tooltip_shown = false
var purchase_count = 0
var max_purchases = 1

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
	purchase_count = 0  # Reset purchase count when setting up
	
	print("Setting up tattoo: ", tattoo_data.name)
	
	if icon and tattoo_data.icon_texture:
		icon.texture = tattoo_data.icon_texture
	
	if cost_label:
		cost_label.text = str(tattoo_data.cost) + " Gold"
	
	update_visual_state()

func mark_as_purchased():
	purchase_count += 1
	update_visual_state()
	print("📦 Tattoo purchased count: ", purchase_count, "/", max_purchases)

func update_visual_state():
	if purchase_count >= max_purchases:
		# Gray out and disable
		modulate = Color(0.5, 0.5, 0.5, 0.7)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if cost_label:
			cost_label.text = "SOLD OUT"
	else:
		# Normal appearance
		modulate = Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_STOP
		if tattoo_data and cost_label:
			cost_label.text = str(tattoo_data.cost) + " Gold"

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				tooltip_shown = false  # Hide tooltip when dragging starts
				emit_signal("tattoo_dragged", tattoo_data, self)
				emit_signal("drag_started", tattoo_data)
				emit_signal("hide_tooltip")
			else:
				if is_dragging:
					is_dragging = false
					emit_signal("drag_ended")

func _get_drag_data(position):
	if tattoo_data and purchase_count < max_purchases:
		print("🎯 DRAGGING: ", tattoo_data.name)
		
		# CHECK IF WE CAN AFFORD IT FIRST
		var shop_manager = get_tree().get_first_node_in_group("shop")
		if shop_manager and shop_manager.has_method("can_afford_tattoo"):
			if not shop_manager.can_afford_tattoo(tattoo_data):
				print("❌ Cannot afford tattoo: ", tattoo_data.name)
				return null
		
		tooltip_shown = false
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
	
	# Only show tooltip once when mouse enters (not on every movement)
	if tattoo_data and not is_dragging and not tooltip_shown:
		tooltip_shown = true
		var tooltip_pos = global_position + Vector2(size.x / 2, 0)
		emit_signal("show_tooltip", tattoo_data.name, tattoo_data.description, tooltip_pos)

func _mouse_exited():
	is_mouse_inside = false
	tooltip_shown = false  # Reset tooltip state when mouse leaves
	emit_signal("hide_tooltip")

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		if is_dragging:
			is_dragging = false
			tooltip_shown = false  # Reset tooltip state when drag ends
			emit_signal("drag_ended")
