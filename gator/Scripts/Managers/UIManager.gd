# UIManager.gd
# Centralized UI management and updates
extends Node

signal continue_to_shop
signal shop_closed(teeth_mapping: Dictionary, artifacts: Array)

var ui_config: UIConfig
var game_ui: CanvasLayer
var round_transition: CanvasLayer
var shop: CanvasLayer

func setup(config: UIConfig, game_ui_ref: CanvasLayer, transition_ref: CanvasLayer):
	ui_config = config
	game_ui = game_ui_ref
	round_transition = transition_ref
	
	# Find shop reference
	shop = get_node("../Shop")
	
	# Connect signals
	connect_ui_signals()
	
	print("✅ UIManager initialized")

func connect_ui_signals():
	if round_transition and round_transition.has_signal("continue_pressed"):
		round_transition.continue_pressed.connect(_on_continue_pressed)
	
	if shop and shop.has_signal("shop_closed"):
		shop.shop_closed.connect(_on_shop_closed)

func update_score(score: int):
	if game_ui and game_ui.has_method("update_score"):
		game_ui.update_score(score)

func update_total_score(total: int, target: int):
	if game_ui and game_ui.has_method("update_total_score"):
		game_ui.update_total_score(total, target)

func update_round(current: int, max_rounds: int):
	if game_ui and game_ui.has_method("update_round"):
		game_ui.update_round(current, max_rounds)

func update_level(level: int):
	if game_ui and game_ui.has_method("update_level"):
		game_ui.update_level(level)

func update_money(amount: int):
	if game_ui and game_ui.has_method("update_money"):
		game_ui.update_money(amount)

func update_level_display(level_data: LevelData):
	if game_ui:
		if game_ui.has_method("update_goal"):
			game_ui.update_goal(level_data.target_score)
		if game_ui.has_method("update_level"):
			game_ui.update_level(level_data.level_number)

func start_round(round_number: int, max_rounds: int):
	update_round(round_number, max_rounds)
	
	if game_ui and game_ui.has_method("hide_end_round_button"):
		game_ui.hide_end_round_button()

func show_score_popup(value: int, world_position: Vector3, is_multiplier: bool = false):
	if not game_ui or not game_ui.has_method("show_score_popup"):
		return
	
	# Convert 3D world position to 2D screen position
	var camera = get_viewport().get_camera_3d()
	var screen_pos = Vector2(640, 360)  # Default center
	
	if camera:
		screen_pos = camera.unproject_position(world_position)
	
	game_ui.show_score_popup(value, screen_pos, is_multiplier)

func show_round_transition(round_score: int, money_earned: int, total_score: int, target_score: int):
	if round_transition and round_transition.has_method("show_results"):
		round_transition.show_results(round_score, money_earned, total_score, target_score)

func show_bite_survival_message():
	# Show special UI for bite survival
	if game_ui and game_ui.has_method("show_end_round_button"):
		game_ui.show_end_round_button()
	
	# Could add more dramatic feedback here
	print("✨ BITE SURVIVAL ACTIVATED!")

func open_shop(money: int, shop_config: ShopConfig):
	if shop and shop.has_method("open_shop"):
		shop.open_shop(money)

func create_floating_text(text: String, position: Vector2, color: Color = Color.WHITE):
	# Create floating text effect
	var label = Label.new()
	label.text = text
	label.position = position
	label.add_theme_color_override("font_color", color)
	
	get_tree().current_scene.add_child(label)
	
	# Animate the text
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", position.y - ui_config.score_popup_rise_distance, ui_config.score_popup_duration)
	tween.tween_property(label, "modulate:a", 0.0, ui_config.score_popup_duration)
	
	# Clean up
	tween.tween_callback(label.queue_free).set_delay(ui_config.score_popup_duration)

func show_tooltip(item_name: String, description: String, position: Vector2):
	# Forward to any tooltip system
	pass

func hide_tooltip():
	# Forward to any tooltip system
	pass

func show_notification(message: String, duration: float = 2.0):
	print("📢 Notification: ", message)
	# Could create actual notification UI here

func show_error_message(message: String):
	print("❌ Error: ", message)
	# Could create error popup here

func show_success_message(message: String):
	print("✅ Success: ", message)
	# Could create success popup here

# Screen effects
func screen_shake(intensity: float = 10.0, duration: float = 0.3):
	if not ui_config.enable_screen_shake:
		return
	
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	var original_position = camera.position
	var tween = create_tween()
	
	# Shake effect
	for i in range(int(duration * 30)):  # 30 FPS shake
		var offset = Vector3(
			randf_range(-intensity, intensity) * 0.01,
			randf_range(-intensity, intensity) * 0.01,
			0
		)
		tween.tween_property(camera, "position", original_position + offset, 1.0/30.0)
	
	# Return to original position
	tween.tween_property(camera, "position", original_position, 0.1)

func flash_screen(color: Color = Color.WHITE, intensity: float = 0.5, duration: float = 0.2):
	# Create screen flash effect
	var flash_rect = ColorRect.new()
	flash_rect.color = Color(color.r, color.g, color.b, intensity)
	flash_rect.anchors_preset = Control.PRESET_FULL_RECT
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	get_tree().current_scene.add_child(flash_rect)
	
	var tween = create_tween()
	tween.tween_property(flash_rect, "modulate:a", 0.0, duration)
	tween.tween_callback(flash_rect.queue_free)

# Signal handlers
func _on_continue_pressed():
	emit_signal("continue_to_shop")

func _on_shop_closed(teeth_mapping: Dictionary, artifacts: Array):
	emit_signal("shop_closed", teeth_mapping, artifacts)

# Utility functions
func is_ui_element_visible(element_name: String) -> bool:
	# Check if specific UI elements are visible
	match element_name:
		"game_ui":
			return game_ui and game_ui.visible
		"shop":
			return shop and shop.visible
		"transition":
			return round_transition and round_transition.visible
		_:
			return false

func set_ui_element_visibility(element_name: String, visible: bool):
	match element_name:
		"game_ui":
			if game_ui:
				game_ui.visible = visible
		"shop":
			if shop:
				shop.visible = visible
		"transition":
			if round_transition:
				round_transition.visible = visible

func get_ui_scale() -> float:
	return ui_config.ui_scale if ui_config else 1.0

# Animation helpers
func animate_ui_element(element: Control, property: String, target_value, duration: float = 0.3):
	if not element:
		return
	
	var tween = create_tween()
	tween.tween_property(element, property, target_value, duration)
