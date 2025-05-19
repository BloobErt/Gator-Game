extends Area3D

func _ready():
	print("Tooth area initialized: ", name)
	input_event.connect(_on_input_event)

func _on_input_event(camera, event, position, normal, shape_idx):
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Tooth clicked: ", name)
		var controller = get_parent()
		controller.press_tooth(name)
