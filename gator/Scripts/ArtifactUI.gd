# Create a new script: ArtifactUI.gd
extends CanvasLayer

signal artifact_used(artifact_id, target_tooth)

var active_artifacts: Array[ArtifactData] = []
var artifact_buttons: Array[Button] = []

@onready var artifact_container = $ArtifactContainer
@onready var selection_overlay = $SelectionOverlay

func _ready():
	# Set this layer above the game UI
	layer = 1  # Game UI is on -1, so 1 puts this on top
	
	# Hide selection overlay initially
	if selection_overlay:
		selection_overlay.visible = false

# Called by GameManager when artifacts are added
func setup_artifacts(artifacts: Array[ArtifactData]):
	active_artifacts = artifacts
	create_artifact_buttons()

func create_artifact_buttons():
	# Clear existing buttons
	for button in artifact_buttons:
		if is_instance_valid(button):
			button.queue_free()
	artifact_buttons.clear()
	
	# Create buttons for active artifacts
	for i in range(active_artifacts.size()):
		var artifact = active_artifacts[i]
		if artifact.is_active_artifact and artifact.uses_remaining != 0:
			create_artifact_button(artifact, i)

func create_artifact_button(artifact: ArtifactData, index: int):
	var button = Button.new()
	button.text = artifact.name
	button.custom_minimum_size = Vector2(120, 40)
	
	# Position buttons horizontally at the bottom
	button.position = Vector2(10 + (index * 130), get_viewport().size.y - 60)
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_top = -60
	button.offset_bottom = -20
	
	# Style the button based on artifact rarity
	style_artifact_button(button, artifact)
	
	# Connect signal
	button.pressed.connect(_on_artifact_button_pressed.bind(artifact))
	
	# Add to container
	artifact_container.add_child(button)
	artifact_buttons.append(button)
	
	# Add tooltip
	button.tooltip_text = artifact.description + "\nUses: " + str(artifact.uses_remaining)

func style_artifact_button(button: Button, artifact: ArtifactData):
	var style = StyleBoxFlat.new()
	
	# Color based on rarity
	match artifact.rarity:
		"common":
			style.bg_color = Color.GRAY
		"rare":
			style.bg_color = Color.BLUE
		"epic":
			style.bg_color = Color.PURPLE
		"legendary":
			style.bg_color = Color.GOLD
		_:
			style.bg_color = Color.WHITE
	
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	
	button.add_theme_stylebox_override("normal", style)

func _on_artifact_button_pressed(artifact: ArtifactData):
	print("Artifact button pressed: ", artifact.name)
	
	# Check if this artifact needs target selection
	if needs_target_selection(artifact):
		start_tooth_selection(artifact)
	else:
		# Use artifact without target
		emit_signal("artifact_used", artifact.id, "")

func needs_target_selection(artifact: ArtifactData) -> bool:
	# Return true for artifacts that need to target a specific tooth
	return artifact.id in ["tooth_modifier", "safe_tooth_revealer"]

func start_tooth_selection(artifact: ArtifactData):
	print("Starting tooth selection for: ", artifact.name)
	
	# Show selection overlay
	if selection_overlay:
		selection_overlay.visible = true
		selection_overlay.setup_for_artifact(artifact)
	
	# You could also highlight available teeth here
	highlight_selectable_teeth(artifact)

func highlight_selectable_teeth(artifact: ArtifactData):
	# This would highlight teeth that can be targeted
	# Implementation depends on your 3D scene setup
	print("Highlighting selectable teeth for: ", artifact.name)

func end_tooth_selection():
	if selection_overlay:
		selection_overlay.visible = false
	
	# Remove highlights
	remove_tooth_highlights()

func remove_tooth_highlights():
	# Remove any tooth highlighting
	print("Removing tooth highlights")

# Update button states when artifacts are used
func update_artifact_displays():
	for i in range(artifact_buttons.size()):
		if i < active_artifacts.size():
			var artifact = active_artifacts[i]
			var button = artifact_buttons[i]
			
			if artifact.uses_remaining <= 0:
				button.disabled = true
				button.text = artifact.name + " (Exhausted)"
			else:
				button.tooltip_text = artifact.description + "\nUses: " + str(artifact.uses_remaining)
