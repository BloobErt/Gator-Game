extends Camera3D

# Reference to the alligator controller
@onready var alligator_controller = get_node("../Alligator")

func _ready():
	# Verify the controller was found
	if not alligator_controller:
		push_error("Could not find AlligatorController node!")
		print("Could not find AlligatorController, check the path!")

# Add to the camera script
func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var from = project_ray_origin(event.position)
		var to = from + project_ray_normal(event.position) * 1000.0
		
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)
