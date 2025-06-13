extends Control

signal tooth_selected(tooth_name)
signal selection_cancelled

var current_artifact: ArtifactData
@onready var instruction_label = $InstructionLabel
@onready var cancel_button = $CancelButton

func _ready():
	cancel_button.pressed.connect(_on_cancel_pressed)

func setup_for_artifact(artifact: ArtifactData):
	current_artifact = artifact
	
	# Update instruction text based on artifact
	match artifact.id:
		"tooth_modifier":
			instruction_label.text = "Click on a tooth with no tattoos to modify"
		"safe_tooth_revealer":
			instruction_label.text = "Click anywhere to reveal safe teeth"
		_:
			instruction_label.text = "Click on a tooth to target"

func _on_cancel_pressed():
	emit_signal("selection_cancelled")

# Handle tooth selection via raycast
func _input(event):
	if not visible:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Perform raycast to find clicked tooth
		var camera = get_viewport().get_camera_3d()
		if camera:
			var from = camera.project_ray_origin(event.position)
			var to = from + camera.project_ray_normal(event.position) * 1000.0
			
			# Get the 3D world from the viewport instead of self
			var space_state = get_viewport().get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(from, to)
			var result = space_state.intersect_ray(query)
			
			if result:
				var collider = result.get("collider")
				if collider and "Tooth" in collider.name:
					emit_signal("tooth_selected", collider.name)
					return
		
		# If no tooth was clicked, treat as "anywhere" click for some artifacts
		if current_artifact and current_artifact.id == "safe_tooth_revealer":
			emit_signal("tooth_selected", "")  # Empty string means "anywhere"
