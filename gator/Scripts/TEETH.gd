extends Area3D

func _ready():
	input_event.connect(_on_input_event)

func _on_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var controller = get_parent()
		
		# Make sure we're passing a String
		var tooth_name = String(name)
		
		print("Clicked on tooth: ", tooth_name)
		controller.press_tooth(tooth_name)
