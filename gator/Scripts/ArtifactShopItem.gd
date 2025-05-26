extends Control

signal artifact_purchased(artifact_data, cost)
signal show_tooltip(item_name, description, position)
signal hide_tooltip()

var artifact_data: ArtifactData
var is_purchased = false
var is_mouse_inside = false

@onready var icon = $Icon
@onready var cost_label = $CostLabel
@onready var background = $Background

func _ready():
	# Connect mouse signals manually
	if not is_connected("mouse_entered", _mouse_entered):
		mouse_entered.connect(_mouse_entered)
	
	if not is_connected("mouse_exited", _mouse_exited):
		mouse_exited.connect(_mouse_exited)

func setup_artifact(data: ArtifactData):
	artifact_data = data
	
	if icon and artifact_data.icon_texture:
		icon.texture = artifact_data.icon_texture
	
	if cost_label:
		cost_label.text = str(artifact_data.cost) + " Gold"
	
	update_visual_state()

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_purchased and artifact_data:
			emit_signal("artifact_purchased", artifact_data, artifact_data.cost)
			# Hide tooltip when clicking
			emit_signal("hide_tooltip")
	
	elif event is InputEventMouseMotion and is_mouse_inside and artifact_data:
		# Update tooltip position on mouse movement
		emit_signal("show_tooltip", artifact_data.name, artifact_data.description, 
				   global_position + event.position)

func _mouse_entered():
	is_mouse_inside = true
	
	if artifact_data:
		var tooltip_pos = global_position + Vector2(size.x / 2, 0)
		emit_signal("show_tooltip", artifact_data.name, artifact_data.description, tooltip_pos)

func _mouse_exited():
	is_mouse_inside = false
	emit_signal("hide_tooltip")

func mark_as_purchased():
	is_purchased = true
	update_visual_state()

func mark_as_available():
	is_purchased = false
	update_visual_state()

func update_visual_state():
	if is_purchased:
		# Visual feedback for purchased artifact
		modulate = Color(0.5, 0.5, 0.5, 0.7)  # Grayed out
		if cost_label:
			cost_label.text = "OWNED"
	else:
		# Normal appearance
		modulate = Color.WHITE
		if artifact_data and cost_label:
			cost_label.text = str(artifact_data.cost) + " Gold"
