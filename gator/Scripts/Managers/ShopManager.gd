# ShopManager.gd
# Main coordinator for the shop system
extends CanvasLayer

signal shop_closed(teeth_tattoo_mapping: Dictionary, purchased_artifacts: Array)
signal tooth_selected_for_artifact(slot_index: int)

# Sub-managers
@onready var item_generator = $ShopItemGenerator
@onready var tooth_drawer = $TeethDrawerManager  
@onready var shop_ui = $ShopUI
@onready var purchase_handler = $PurchaseHandler

# Shop state
var shop_config: ShopConfig
var current_money: int = 0
var newly_purchased_artifacts: Array[ArtifactData] = []

func _ready():
	layer = 2
	visible = false
	
	# Add to shop group for easy reference
	add_to_group("shop")
	
	setup_manager_connections()

func setup_manager_connections():
	print("🔗 Setting up ShopManager signal connections")
	
	# Connect sub-manager signals
	if purchase_handler:
		purchase_handler.item_purchased.connect(_on_item_purchased)
		purchase_handler.money_changed.connect(_on_money_changed)
		print("✅ Connected PurchaseHandler signals")
	
	if tooth_drawer:
		tooth_drawer.tooth_selected.connect(_on_tooth_selected_for_artifact)
		# CONNECT TATTOO APPLICATION SIGNAL
		for i in range(16):  # Connect all tooth slots
			var teeth_slots = tooth_drawer.get_teeth_slots()
			if i < teeth_slots.size():
				var tooth_slot = teeth_slots[i]
				if not tooth_slot.is_connected("tattoo_applied", _on_tattoo_applied_to_slot):
					tooth_slot.tattoo_applied.connect(_on_tattoo_applied_to_slot)
		print("✅ Connected ToothDrawer signals")
	
	if shop_ui:
		shop_ui.exit_requested.connect(_on_exit_requested)
		shop_ui.clear_tooth_requested.connect(_on_clear_tooth_requested)
		shop_ui.artifact_purchase_requested.connect(_on_artifact_purchase_requested)
		print("✅ Connected ShopUI signals")
	
	print("🔗 All ShopManager signals connected")

# === PUBLIC INTERFACE ===

func open_shop(money: int, config: ShopConfig = null):
	print("ShopManager.open_shop called with money: ", money)
	
	current_money = money
	if config:
		shop_config = config
	
	# Clear newly purchased artifacts when opening shop
	newly_purchased_artifacts.clear()
	
	# Setup all sub-managers
	setup_shop_systems()
	
	# Generate shop content
	generate_shop_content()
	
	# Show the shop
	visible = true
	print("Shop visibility set to: ", visible)

func close_shop():
	print("🏪 Closing shop...")
	
	# Close drawer if it's open
	if tooth_drawer and tooth_drawer.is_drawer_open:
		print("🎯 Closing drawer before shop exit")
		tooth_drawer.close_drawer()
		# Wait for drawer to close
		await get_tree().create_timer(0.5).timeout
	
	visible = false
	
	# Get final teeth mapping from drawer
	var final_mapping = {}
	if tooth_drawer:
		final_mapping = tooth_drawer.get_teeth_tattoo_mapping()
	
	# Emit shop closed with results
	print("Passing ", newly_purchased_artifacts.size(), " newly purchased artifacts to game")
	emit_signal("shop_closed", final_mapping, newly_purchased_artifacts.duplicate())

func open_drawer():
	"""Open the teeth drawer for tattoo application"""
	print("🎯 ShopManager: Opening drawer")
	if tooth_drawer:
		tooth_drawer.open_drawer()
	else:
		print("❌ No tooth_drawer found!")

func open_drawer_for_artifact_selection(artifact: ArtifactData):
	"""Open drawer for artifact selection"""
	print("🎯 ShopManager: Opening drawer for artifact selection")
	if tooth_drawer:
		tooth_drawer.open_for_artifact_selection(artifact)
	else:
		print("❌ No tooth_drawer found!")

# === PRIVATE METHODS ===

func setup_shop_systems():
	# Configure item generator
	if item_generator:
		item_generator.setup(shop_config)
	
	# Configure tooth drawer
	if tooth_drawer:
		tooth_drawer.setup()
	
	# Configure shop UI
	if shop_ui:
		shop_ui.setup(current_money)
	
	# Configure purchase handler
	if purchase_handler:
		purchase_handler.setup(current_money)

func generate_shop_content():
	print("=== GENERATING SHOP CONTENT ===")
	
	if not item_generator:
		print("❌ No item generator available")
		return
	
	# Generate tattoos and artifacts
	var tattoos = item_generator.generate_tattoo_selection()
	var artifacts = item_generator.generate_artifact_selection()
	
	print("Generated ", tattoos.size(), " tattoos and ", artifacts.size(), " artifacts")
	
	# Pass to UI for display
	if shop_ui:
		shop_ui.display_tattoos(tattoos)
		shop_ui.display_artifacts(artifacts)

func can_afford_tattoo(tattoo_data: TattooData) -> bool:
	if purchase_handler:
		var cost = purchase_handler.calculate_item_cost(tattoo_data, 1)
		return purchase_handler.can_afford(cost)
	return false

func purchase_tattoo(tattoo_data: TattooData) -> bool:
	if purchase_handler:
		return purchase_handler.attempt_purchase(tattoo_data, "tattoo", 1)
	return false

func mark_tattoo_as_purchased(tattoo_data: TattooData):
	"""Mark a tattoo as purchased in the shop UI"""
	if shop_ui:
		# Find the tattoo slot that contains this tattoo and mark it as purchased
		var tattoo_slots = shop_ui.tattoo_slots
		for slot in tattoo_slots:
			if slot.tattoo_data and slot.tattoo_data.id == tattoo_data.id:
				slot.mark_as_purchased()
				break

# === EVENT HANDLERS ===

func _on_artifact_purchase_requested(artifact_data: ArtifactData):
	print("💰 Processing artifact purchase: ", artifact_data.name)
	
	if purchase_handler:
		var success = purchase_handler.attempt_purchase(artifact_data, "artifact", 1)
		
		if success:
			print("✅ Artifact purchased successfully!")
		else:
			print("❌ Artifact purchase failed!")
	else:
		print("❌ No purchase handler found!")

func _on_item_purchased(item_data, cost: int, item_type: String):
	print("💰 Item purchased: ", item_data.name, " for ", cost, " gold")
	
	# Track newly purchased artifacts
	if item_type == "artifact":
		newly_purchased_artifacts.append(item_data)
		
		# UPDATE: Show artifact as purchased in UI
		if shop_ui:
			var all_owned = newly_purchased_artifacts.duplicate()
			# Add any previously owned artifacts if needed
			shop_ui.update_artifact_ownership_display(all_owned)
	
	# Update money display
	if shop_ui:
		shop_ui.update_money_display(purchase_handler.get_current_money())

func _on_money_changed(new_amount: int):
	current_money = new_amount
	if shop_ui:
		shop_ui.update_money_display(new_amount)

func _on_tattoo_applied_to_slot(slot_index: int, tattoo_data: TattooData):
	print("🎯 Tattoo dropped - attempting purchase: ", tattoo_data.name)
	
	var success = purchase_tattoo(tattoo_data)
	if success:
		print("✅ Tattoo purchased successfully!")
		
		# Mark the tattoo as purchased in the shop UI
		mark_tattoo_as_purchased(tattoo_data)
		
	else:
		print("❌ Tattoo purchase failed - removing from slot")
		# Remove the tattoo from the slot since purchase failed
		var teeth_slots = get_teeth_slots()
		if slot_index < teeth_slots.size():
			var tooth_slot = teeth_slots[slot_index]
			if tooth_slot.applied_tattoos.size() > 0:
				tooth_slot.applied_tattoos.pop_back()  # Remove the last added tattoo
				tooth_slot.update_display()

func _on_tooth_selected_for_artifact(slot_index: int):
	print("Tooth selected for artifact: slot ", slot_index)
	emit_signal("tooth_selected_for_artifact", slot_index)
	
	# Close drawer after selection
	if tooth_drawer:
		tooth_drawer.close_drawer()

func _on_exit_requested():
	close_shop()

func _on_clear_tooth_requested():
	# Handle tooth clearing logic
	if purchase_handler and purchase_handler.can_afford_tooth_clear():
		print("💰 Clearing tooth for ", purchase_handler.get_tooth_clear_cost(), " gold")
		purchase_handler.spend_money(purchase_handler.get_tooth_clear_cost(), "tooth_clearing")

# === UTILITY ===

func get_teeth_slots():
	"""Delegate to tooth drawer manager"""
	if tooth_drawer:
		return tooth_drawer.get_teeth_slots()
	return []

func close_drawer():
	"""Close the teeth drawer"""
	print("🎯 ShopManager: Closing drawer")
	if tooth_drawer:
		tooth_drawer.close_drawer()

func is_open() -> bool:
	return visible

# === DEBUG ===

func debug_shop_state():
	print("=== SHOP DEBUG ===")
	print("Visible: ", visible)
	print("Money: ", current_money)
	print("Newly purchased artifacts: ", newly_purchased_artifacts.size())
	
	if item_generator:
		item_generator.debug_available_items()
	
	if tooth_drawer:
		tooth_drawer.debug_teeth_state()
