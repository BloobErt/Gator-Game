# ArtifactUI.gd - Fixed version
extends CanvasLayer

signal artifact_used(artifact_id, target_tooth)

var active_artifacts: Array[ArtifactData] = []
var artifact_icons: Array[Control] = []
var current_selection_artifact: ArtifactData = null

@onready var left_side_container = $LeftSideContainer
@onready var right_side_container = $RightSideContainer
@onready var selection_overlay = $SelectionOverlay

# Reference to the shop's tooth drawer system
var shop_reference = null

func _ready():
	layer = 1
	
	if selection_overlay:
		selection_overlay.visible = false
		# Connect selection overlay signals
		selection_overlay.tooth_selected.connect(_on_tooth_selected_from_overlay)
		selection_overlay.selection_cancelled.connect(_on_artifact_selection_cancelled)
	
	# Get reference to shop
	shop_reference = get_node("../Shop")  # Should still work
	if not shop_reference:
		shop_reference = get_node("../../Shop")  # Try parent's parent
	if not shop_reference:
		shop_reference = get_tree().get_first_node_in_group("shop")
	
	print("ArtifactUI shop reference: ", shop_reference)

func setup_artifacts(artifacts: Array[ArtifactData]):
	print("=== SETTING UP ARTIFACTS ===")
	print("Number of artifacts received: ", artifacts.size())
	
	active_artifacts = artifacts
	create_artifact_icons()

func create_artifact_icons():
	# Clear existing icons
	for icon in artifact_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	artifact_icons.clear()
	
	# Create icons for all owned artifacts
	for i in range(active_artifacts.size()):
		var artifact = active_artifacts[i]
		create_artifact_icon(artifact, i)

func create_artifact_icon(artifact: ArtifactData, index: int):
	print("Creating icon for artifact: ", artifact.name)
	
	var icon_container = Control.new()
	icon_container.custom_minimum_size = Vector2(80, 80)
	icon_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var texture_rect = TextureRect.new()
	texture_rect.texture = artifact.icon_texture
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.position = Vector2(5, 5)
	texture_rect.size = Vector2(70, 55)
	
	var background = Panel.new()
	background.position = Vector2(0, 0)
	background.size = Vector2(80, 80)
	style_artifact_background(background, artifact)
	
	icon_container.add_child(background)
	icon_container.add_child(texture_rect)
	
	# Add uses label if it's an active artifact
	if artifact.is_active_artifact and artifact.uses_remaining > 0:
		var uses_label = Label.new()
		uses_label.text = str(artifact.uses_remaining)
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
	
	# Decide which side to place it on
	var target_container = left_side_container if (index % 2 == 0) else right_side_container
	target_container.add_child(icon_container)
	artifact_icons.append(icon_container)

func style_artifact_background(panel: Panel, artifact: ArtifactData):
	var style = StyleBoxFlat.new()
	
	match artifact.rarity:
		"common":
			style.bg_color = Color(0.5, 0.5, 0.5, 0.8)
		"rare":
			style.bg_color = Color(0.2, 0.4, 0.8, 0.8)
		"epic":
			style.bg_color = Color(0.6, 0.2, 0.8, 0.8)
		"legendary":
			style.bg_color = Color(0.8, 0.6, 0.2, 0.8)
		_:
			style.bg_color = Color(0.3, 0.3, 0.3, 0.8)
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color.WHITE
	
	panel.add_theme_stylebox_override("panel", style)

func _on_artifact_icon_input(event: InputEvent, artifact: ArtifactData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Artifact icon clicked: ", artifact.name)
		
		if needs_target_selection(artifact):
			start_tooth_selection_with_drawer(artifact)
		else:
			# Use artifact immediately
			emit_signal("artifact_used", artifact.id, "")

func needs_target_selection(artifact: ArtifactData) -> bool:
	return artifact.id in ["tooth_modifier"]

func start_tooth_selection_with_drawer(artifact: ArtifactData):
	print("Starting tooth selection with drawer for: ", artifact.name)
	
	current_selection_artifact = artifact
	
	# NEW: Updated method call
	if shop_reference and shop_reference.has_method("open_drawer_for_artifact_selection"):
		shop_reference.open_drawer_for_artifact_selection(artifact)
	else:
		print("ERROR: Cannot open shop drawer for artifact selection!")

# This is called when the shop emits tooth_selected_for_artifact
func _on_tooth_selected_from_drawer(tooth_slot_index: int):
	print("Tooth selected from drawer: slot ", tooth_slot_index)
	
	if current_selection_artifact:
		var tooth_identifier = "slot_" + str(tooth_slot_index)
		emit_signal("artifact_used", current_selection_artifact.id, tooth_identifier)
		
		current_selection_artifact = null
		
		if shop_reference and shop_reference.has_method("close_drawer"):
			shop_reference.close_drawer()

# This is called when using the selection overlay (for 3D tooth selection)
func _on_tooth_selected_from_overlay(tooth_name: String):
	print("Tooth selected from overlay: ", tooth_name)
	
	if current_selection_artifact:
		emit_signal("artifact_used", current_selection_artifact.id, tooth_name)
		
		current_selection_artifact = null
		
		if selection_overlay:
			selection_overlay.visible = false

func _on_artifact_selection_cancelled():
	print("Artifact selection cancelled")
	current_selection_artifact = null
	
	if selection_overlay:
		selection_overlay.visible = false
	
	if shop_reference and shop_reference.has_method("close_drawer"):
		shop_reference.close_drawer()

func end_tooth_selection():
	print("Ending tooth selection")
	current_selection_artifact = null
	
	if selection_overlay:
		selection_overlay.visible = false
	
	if shop_reference and shop_reference.has_method("close_drawer"):
		shop_reference.close_drawer()

func update_artifact_displays():
	# Recreate all icons to reflect current state
	create_artifact_icons()
