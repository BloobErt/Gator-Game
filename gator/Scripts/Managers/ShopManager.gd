# ShopManager.gd
# Main coordinator for the shop system
extends CanvasLayer

signal shop_closed(teeth_tattoo_mapping: Dictionary, purchased_artifacts: Array)
signal tooth_selected_for_artifact(slot_index: int)

# Sub-managers
@onready var item_generator = $ShopItemGenerator
@onready var tooth_drawer = $ToothDrawerManager  
@onready var shop_ui = $ShopUI
@onready var purchase_handler = $PurchaseHandler

# Shop state
var shop_config: ShopConfig
var current_money: int = 0
var newly_purchased_artifacts: Array[ArtifactData] = []

func _ready():
	layer = 2
	visible = false
	setup_manager_connections()

func setup_manager_connections():
	# Connect sub-manager signals
	if purchase_handler:
		purchase_handler.item_purchased.connect(_on_item_purchased)
		purchase_handler.money_changed.connect(_on_money_changed)
	
	if tooth_drawer:
		tooth_drawer.tooth_selected.connect(_on_tooth_selected_for_artifact)
	
	if shop_ui:
		shop_ui.exit_requested.connect(_on_exit_requested)
		shop_ui.clear_tooth_requested.connect(_on_clear_tooth_requested)

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
	visible = false
	
	# Get final teeth mapping from drawer
	var final_mapping = {}
	if tooth_drawer:
		final_mapping = tooth_drawer.get_teeth_tattoo_mapping()
	
	# Emit shop closed with results
	print("Passing ", newly_purchased_artifacts.size(), " newly purchased artifacts to game")
	emit_signal("shop_closed", final_mapping, newly_purchased_artifacts.duplicate())

func open_drawer_for_artifact_selection(artifact: ArtifactData):
	"""Delegate to tooth drawer manager"""
	if tooth_drawer:
		tooth_drawer.open_for_artifact_selection(artifact)

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

# === EVENT HANDLERS ===

func _on_item_purchased(item_data, cost: int, item_type: String):
	print("💰 Item purchased: ", item_data.name, " for ", cost, " gold")
	
	# Track newly purchased artifacts
	if item_type == "artifact":
		newly_purchased_artifacts.append(item_data)
	
	# Update money display
	if shop_ui:
		shop_ui.update_money_display(purchase_handler.get_current_money())

func _on_money_changed(new_amount: int):
	current_money = new_amount
	if shop_ui:
		shop_ui.update_money_display(new_amount)

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
	"""Delegate to tooth drawer manager"""
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
