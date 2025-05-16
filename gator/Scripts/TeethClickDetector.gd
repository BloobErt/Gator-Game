extends Camera3D

# Reference to the alligator controller
@onready var alligator_controller = get_node("../Alligator")

func _ready():
	# Verify the controller was found
	if not alligator_controller:
		push_error("Could not find AlligatorController node!")
		print("Could not find AlligatorController, check the path!")
