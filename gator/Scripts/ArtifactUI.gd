# ArtifactUI.gd - Updated for side layout
extends CanvasLayer

signal artifact_used(artifact_id, target_tooth)

var active_artifacts: Array[ArtifactData] = []
var artifact_icons: Array[Control] = []

# Update these to match your new scene structure
@onready var left_side_container = $LeftSideContainer
@onready var right_side_container = $RightSideContainer
@onready var selection_overlay = $SelectionOverlay

func _ready():
	# Set this layer above the game UI
	layer = 1  # Game UI is on -1, so 1 puts this on top
	
	# Hide selection overlay initially
	if selection_overlay:
		selection_overlay.visible = false

# Called by GameManager when artifacts are added
func setup_artifacts(artifacts: Array[ArtifactData]):
	print("=== SETTING UP ARTIFACTS ===")
	print("Number of artifacts received: ", artifacts.size())
	for i in range(artifacts.size()):
		print("Artifact ", i, ": ", artifacts[i].name, " | Texture: ", artifacts[i].icon_texture)
	
	active_artifacts = artifacts
	create_artifact_icons()

func create_artifact_icons():
	# Clear existing icons
	for icon in artifact_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	artifact_icons.clear()
	
	# Create icons for all owned artifacts (not just active ones)
	for i in range(active_artifacts.size()):
		var artifact = active_artifacts[i]
		create_artifact_icon(artifact, i)

func create_artifact_icon(artifact: ArtifactData, index: int):
	print("Creating icon for artifact: ", artifact.name)
	print("Artifact icon_texture: ", artifact.icon_texture)
	
	# Create the icon container
	var icon_container = Control.new()
	icon_container.custom_minimum_size = Vector2(80, 80)
	icon_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Create the texture rect for the artifact icon
	var texture_rect = TextureRect.new()
	texture_rect.texture = artifact.icon_texture
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Instead of using anchors, set explicit size and position
	texture_rect.position = Vector2(5, 5)
	texture_rect.size = Vector2(70, 55)  # Leave space for uses label at bottom
	
	print("TextureRect created with texture: ", texture_rect.texture)
	print("TextureRect size: ", texture_rect.size)
	
	# Add background/border based on rarity (simplified)
	var background = Panel.new()
	# Set explicit size instead of anchors
	background.position = Vector2(0, 0)
	background.size = Vector2(80, 80)
	style_artifact_background(background, artifact)
	
	icon_container.add_child(background)
	icon_container.add_child(texture_rect)
	
	# Add uses label if it's an active artifact
	if artifact.is_active_artifact and artifact.uses_remaining > 0:
		var uses_label = Label.new()
		uses_label.text = str(artifact.uses_remaining)
		# Set explicit position instead of anchors
		uses_label.position = Vector2(5, 60)
		uses_label.size = Vector2(70, 20)
		uses_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		uses_label.add_theme_color_override("font_color", Color.WHITE)
		uses_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		uses_label.add_theme_constant_override("shadow_offset_x", 1)
		uses_label.add_theme_constant_override("shadow_offset_y", 1)
		icon_container.add_child(uses_label)
		
		# Make it clickable for active artifacts
		icon_container.gui_input.connect(_on_artifact_icon_input.bind(artifact))
	
	# Add tooltip
	var tooltip_text = artifact.name + "\n" + artifact.description
	if artifact.is_active_artifact and artifact.uses_remaining > 0:
		tooltip_text += "\nUses: " + str(artifact.uses_remaining) + "\nClick to use"
	icon_container.tooltip_text = tooltip_text
	
	# Decide which side to place it on (alternate left/right)
	var target_container = left_side_container if (index % 2 == 0) else right_side_container
	target_container.add_child(icon_container)
	artifact_icons.append(icon_container)
	
	print("Added artifact icon to container. Total icons: ", artifact_icons.size())

func style_artifact_background(panel: Panel, artifact: ArtifactData):
	# Create a simple colored background based on rarity
	var style = StyleBoxFlat.new()
	
	# Color based on rarity
	match artifact.rarity:
		"common":
			style.bg_color = Color(0.5, 0.5, 0.5, 0.8)  # Gray
		"rare":
			style.bg_color = Color(0.2, 0.4, 0.8, 0.8)  # Blue
		"epic":
			style.bg_color = Color(0.6, 0.2, 0.8, 0.8)  # Purple
		"legendary":
			style.bg_color = Color(0.8, 0.6, 0.2, 0.8)  # Gold
		_:
			style.bg_color = Color(0.3, 0.3, 0.3, 0.8)  # Default gray
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color.WHITE
	
	# Apply the style directly to the panel
	panel.add_theme_stylebox_override("panel", style)

func _on_artifact_icon_input(event: InputEvent, artifact: ArtifactData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Artifact icon clicked: ", artifact.name)
		
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

# Update icon states when artifacts are used
func update_artifact_displays():
	# Recreate all icons to reflect current state
	create_artifact_icons()
