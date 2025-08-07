extends Control

signal tattoo_dropped(tattoo_data)

var parent_tooth: RigidBody2D = null

var last_drop_check_time = 0.0
var last_drop_result = false
var drop_check_calls = 0

func _ready():
	# Set up the control for drag and drop
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Set size to cover the tooth
	custom_minimum_size = Vector2(80, 80)
	size = Vector2(80, 80)
	
	# Center on the tooth
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -40
	offset_top = -40
	offset_right = 40
	offset_bottom = 40

func set_parent_tooth(tooth: RigidBody2D):
	parent_tooth = tooth

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if parent_tooth:
			print("Drop area clicked! Tooth ", parent_tooth.slot_index)

func _can_drop_data(position, data):
	drop_check_calls += 1
	
	# Use Engine.get_process_frames() for simple timing
	var current_frame = Engine.get_process_frames()
	
	# Only do the expensive check every 10 frames
	if current_frame % 10 != 0 and drop_check_calls > 1:
		return last_drop_result
	
	if not parent_tooth:
		last_drop_result = false
		return false
	
	var can_drop = (data.has("type") and 
					data.type == "tattoo" and 
					parent_tooth.can_accept_tattoo())
	
	# Only print debug every 30 frames to reduce spam
	if current_frame % 30 == 0:
		print("🎯 CAN DROP CHECK on tooth ", parent_tooth.slot_index)
		print("  Current tattoos: ", parent_tooth.applied_tattoos.size(), "/", parent_tooth.get_effective_max_tattoos())
		print("  Result: ", can_drop)
	
	last_drop_result = can_drop
	return can_drop

func _drop_data(position, data):
	print("🎯 DROP RECEIVED on tooth ", parent_tooth.slot_index if parent_tooth else "unknown")
	
	if data.has("type") and data.type == "tattoo":
		var tattoo_data = data.data
		print("✅ Processing drop of ", tattoo_data.name, " to tooth ", parent_tooth.slot_index if parent_tooth else "unknown")
		emit_signal("tattoo_dropped", tattoo_data)
	else:
		print("❌ Invalid drop data")
