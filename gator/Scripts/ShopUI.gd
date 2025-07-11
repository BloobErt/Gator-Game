# ShopUI.gd
# Handles all shop UI display, tooltips, and visual interactions
extends Control

signal exit_requested
signal clear_tooth_requested
signal tattoo_dragged(tattoo_data: TattooData, source_control)
signal artifact_purchase_requested(artifact_data: ArtifactData)

# UI References
@onready var money_label = $ShopContainer/MoneyDisplay/MoneyLabel
@onready var tattoo_slots = [$ShopContainer/TattooSection/TattooContainer/TattooSlot1,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot2,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot3,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot4,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot5]
@onready var artifact_slots = [$ShopContainer/ArtifactSection/ArtifactContainer/ArtifactSlot1,
							   $ShopContainer/ArtifactSection/ArtifactContainer/ArtifactSlot2,
							   $ShopContainer/ArtifactSection/ArtifactContainer/ArtifactSlot3]
@onready var tooltip = $Tooltip
@onready var exit_button = $ExitButton
@onready var clear_tooth_button = $ShopContainer/ArtifactSection/ArtifactContainer/ClearToothButton

# UI State
var current_money: int = 0
var displayed_tattoos: Array[TattooData] = []
var displayed_artifacts: Array[ArtifactData] = []

func _ready():
	setup_ui_connections()

func setup(money: int):
	current_money = money
	update_money_display(money)
	print("✅ ShopUI initialized")

func setup_ui_connections():
	# Connect exit button
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	
	# Connect clear tooth button
	if clear_tooth_button:
		clear_tooth_button.pressed.connect(_on_clear_tooth_pressed)
	
	# Connect tattoo slot signals
	for i in range(tattoo_slots.size()):
		var slot = tattoo_slots[i]
		if slot:
			slot.tattoo_dragged.connect(_on_tattoo_dragged)
			slot.drag_started.connect(_on_drag_started)
			slot.drag_ended.connect(_on_drag_ended)
			slot.show_tooltip.connect(_on_show_tooltip)
			slot.hide_tooltip.connect(_on_hide_tooltip)
	
	# Connect artifact slot signals
	for i in range(artifact_slots.size()):
		var slot = artifact_slots[i]
		if slot:
			slot.artifact_purchased.connect(_on_artifact_purchase_requested)
			slot.show_tooltip.connect(_on_show_tooltip)
			slot.hide_tooltip.connect(_on_hide_tooltip)

# === DISPLAY METHODS ===

func display_tattoos(tattoos: Array[TattooData]):
	displayed_tattoos = tattoos.duplicate()
	
	print("=== DISPLAYING TATTOOS ===")
	print("tattoo_slots.size(): ", tattoo_slots.size())
	print("tattoos.size(): ", tattoos.size())
	
	for i in range(min(tattoos.size(), tattoo_slots.size())):
		if i < tattoo_slots.size() and tattoo_slots[i]:
			print("Setting up tattoo slot ", i, " with: ", tattoos[i].name)
			tattoo_slots[i].setup_tattoo(tattoos[i])
		else:
			print("No tattoo slot available for index ", i)

func display_artifacts(artifacts: Array[ArtifactData]):
	displayed_artifacts = artifacts.duplicate()
	
	print("=== DISPLAYING ARTIFACTS ===")
	print("artifact_slots.size(): ", artifact_slots.size())
	print("artifacts.size(): ", artifacts.size())
	
	for i in range(min(artifacts.size(), artifact_slots.size())):
		if i < artifact_slots.size() and artifact_slots[i]:
			print("Setting up artifact slot ", i, " with: ", artifacts[i].name)
			artifact_slots[i].setup_artifact(artifacts[i])
		else:
			print("No artifact slot available for index ", i)

func update_money_display(amount: int):
	current_money = amount
	if money_label:
		money_label.text = str(amount)
	else:
		print("❌ Money label not found!")

func update_artifact_ownership_display(owned_artifacts: Array[ArtifactData]):
	"""Update artifact slots to show ownership status"""
	for slot in artifact_slots:
		if slot and slot.artifact_data:
			var is_owned = false
			for owned in owned_artifacts:
				if owned.id == slot.artifact_data.id:
					is_owned = true
					break
			
			if is_owned:
				slot.mark_as_purchased()
			else:
				slot.mark_as_available()

# === TOOLTIP SYSTEM ===

func _on_show_tooltip(item_name: String, description: String, position: Vector2):
	print("Show tooltip signal received: ", item_name)
	if tooltip:
		tooltip.show_tooltip(item_name, description, position)
	else:
		print("Tooltip is null!")

func _on_hide_tooltip():
	print("Hide tooltip signal received")
	if tooltip:
		tooltip.hide_tooltip()

func force_hide_tooltips():
	if tooltip:
		tooltip.force_hide()

# === DRAG & DROP SYSTEM ===

func _on_tattoo_dragged(tattoo_data: TattooData, source_control):
	print("Tattoo being dragged: ", tattoo_data.name)
	emit_signal("tattoo_dragged", tattoo_data, source_control)

func _on_drag_started(tattoo_data: TattooData):
	print("Drag started: ", tattoo_data.name)
	force_hide_tooltips()

func _on_drag_ended():
	print("Drag ended")

# === PURCHASE SYSTEM ===

func _on_artifact_purchase_requested(artifact_data: ArtifactData, cost: int):
	print("Artifact purchase requested: ", artifact_data.name, " for ", cost, " gold")
	emit_signal("artifact_purchase_requested", artifact_data)

# === BUTTON HANDLERS ===

func _on_exit_pressed():
	print("Exit button pressed")
	emit_signal("exit_requested")

func _on_clear_tooth_pressed():
	print("Clear tooth button pressed")
	emit_signal("clear_tooth_requested")

# === VISUAL FEEDBACK ===

func show_purchase_success(item_name: String):
	"""Show visual feedback for successful purchases"""
	create_floating_text("Purchased " + item_name + "!", Vector2(640, 200), Color.GREEN)

func show_purchase_failure(reason: String):
	"""Show visual feedback for failed purchases"""
	create_floating_text(reason, Vector2(640, 200), Color.RED)

func create_floating_text(text: String, position: Vector2, color: Color = Color.WHITE):
	var label = Label.new()
	label.text = text
	label.position = position
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	
	add_child(label)
	
	# Animate the text
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", position.y - 50, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	
	# Clean up
	tween.tween_callback(label.queue_free).set_delay(1.0)

func flash_money_display():
	"""Flash the money display when money changes"""
	if money_label:
		var original_color = money_label.get_theme_color("font_color")
		var tween = create_tween()
		tween.tween_property(money_label, "modulate", Color.YELLOW, 0.1)
		tween.tween_property(money_label, "modulate", Color.WHITE, 0.1)

# === ANIMATIONS ===

func animate_slot_purchase(slot_index: int, item_type: String):
	"""Animate a slot when item is purchased"""
	var slots_array = tattoo_slots if item_type == "tattoo" else artifact_slots
	
	if slot_index < slots_array.size():
		var slot = slots_array[slot_index]
		if slot:
			var tween = create_tween()
			tween.tween_property(slot, "scale", Vector2(1.1, 1.1), 0.1)
			tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.1)

func show_shop_opening_animation():
	"""Animate the shop opening"""
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func show_shop_closing_animation():
	"""Animate the shop closing"""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished

# === SHOP STATE MANAGEMENT ===

func enable_interactions():
	"""Enable all shop interactions"""
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	for slot in tattoo_slots:
		if slot:
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
	
	for slot in artifact_slots:
		if slot:
			slot.mouse_filter = Control.MOUSE_FILTER_STOP

func disable_interactions():
	"""Disable shop interactions (for transitions)"""
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	for slot in tattoo_slots:
		if slot:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	for slot in artifact_slots:
		if slot:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

# === UTILITY ===

func get_displayed_tattoos() -> Array[TattooData]:
	return displayed_tattoos.duplicate()

func get_displayed_artifacts() -> Array[ArtifactData]:
	return displayed_artifacts.duplicate()

func clear_all_displays():
	"""Clear all displayed items"""
	for slot in tattoo_slots:
		if slot:
			slot.clear_display()
	
	for slot in artifact_slots:
		if slot:
			slot.clear_display()

# === DEBUG ===

func debug_ui_state():
	print("=== SHOP UI DEBUG ===")
	print("Current money: ", current_money)
	print("Displayed tattoos: ", displayed_tattoos.size())
	print("Displayed artifacts: ", displayed_artifacts.size())
	print("Tooltip visible: ", tooltip.visible if tooltip else "No tooltip")
	
	print("Tattoo slots:")
	for i in range(tattoo_slots.size()):
		var slot = tattoo_slots[i]
		print("  Slot ", i, ": ", slot.tattoo_data.name if (slot and slot.tattoo_data) else "Empty")
	
	print("Artifact slots:")
	for i in range(artifact_slots.size()):
		var slot = artifact_slots[i]
		print("  Slot ", i, ": ", slot.artifact_data.name if (slot and slot.artifact_data) else "Empty")
