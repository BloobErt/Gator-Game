# PurchaseHandler.gd
# Handles all money transactions and purchase logic
extends Node

signal item_purchased(item_data, cost: int, item_type: String)
signal money_changed(new_amount: int)
signal purchase_failed(reason: String)

var current_money: int = 0
var shop_config: ShopConfig
var owned_artifacts: Array[ArtifactData] = []

func setup(money: int, config: ShopConfig = null, artifacts: Array[ArtifactData] = []):
	current_money = money
	shop_config = config
	owned_artifacts = artifacts.duplicate()
	print("✅ PurchaseHandler initialized with ", money, " gold")

# === MONEY MANAGEMENT ===

func get_current_money() -> int:
	return current_money

func can_afford(cost: int) -> bool:
	return current_money >= cost

func spend_money(amount: int, item_type: String = "") -> bool:
	if can_afford(amount):
		current_money -= amount
		emit_signal("money_changed", current_money)
		print("💰 Spent ", amount, " gold on ", item_type, " (Remaining: ", current_money, ")")
		return true
	else:
		print("❌ Cannot afford ", amount, " gold (Have: ", current_money, ")")
		emit_signal("purchase_failed", "Insufficient funds")
		return false

# === PURCHASE LOGIC ===

func attempt_purchase(item_data, item_type: String, current_level: int = 1) -> bool:
	var cost = calculate_item_cost(item_data, current_level)
	
	print("💰 Attempting to purchase ", item_data.name, " for ", cost, " gold")
	
	# Check if we can afford it
	if not can_afford(cost):
		emit_signal("purchase_failed", "Not enough gold! Need " + str(cost) + ", have " + str(current_money))
		return false
	
	# Handle special purchase logic based on item type
	match item_type:
		"tattoo":
			return purchase_tattoo(item_data, cost)
		"artifact":
			return purchase_artifact(item_data, cost)
		_:
			print("❌ Unknown item type: ", item_type)
			return false

func purchase_tattoo(tattoo_data: TattooData, cost: int) -> bool:
	# Tattoos can always be purchased (just for drag & drop)
	if spend_money(cost, "tattoo"):
		emit_signal("item_purchased", tattoo_data, cost, "tattoo")
		return true
	return false

func purchase_artifact(artifact_data: ArtifactData, cost: int) -> bool:
	# Check if artifact is already owned (for evolution)
	var already_owned = false
	var existing_artifact = null
	
	for owned in owned_artifacts:
		if owned.id == artifact_data.id:
			already_owned = true
			existing_artifact = owned
			break
	
	if already_owned and artifact_data.can_evolve:
		return handle_artifact_evolution(artifact_data, existing_artifact, cost)
	elif already_owned and not artifact_data.can_evolve:
		emit_signal("purchase_failed", "Already owned and cannot evolve")
		return false
	else:
		return handle_new_artifact_purchase(artifact_data, cost)

func handle_artifact_evolution(artifact_data: ArtifactData, existing_artifact: ArtifactData, cost: int) -> bool:
	if spend_money(cost, "artifact_evolution"):
		# Remove old version
		owned_artifacts.erase(existing_artifact)
		
		# Add evolved version
		if artifact_data.evolved_form:
			var evolved_copy = artifact_data.evolved_form.duplicate()
			evolved_copy.reset_uses()
			owned_artifacts.append(evolved_copy)
			
			emit_signal("item_purchased", evolved_copy, cost, "artifact")
			print("🔮 Artifact evolved to: ", evolved_copy.name)
			return true
		else:
			print("❌ No evolved form available")
			return false
	return false

func handle_new_artifact_purchase(artifact_data: ArtifactData, cost: int) -> bool:
	if spend_money(cost, "artifact"):
		# Create a copy with reset uses
		var artifact_copy = artifact_data.duplicate()
		artifact_copy.reset_uses()
		owned_artifacts.append(artifact_copy)
		
		emit_signal("item_purchased", artifact_copy, cost, "artifact")
		print("📦 New artifact purchased: ", artifact_copy.name)
		return true
	return false

# === PRICING ===

func calculate_item_cost(item_data, current_level: int = 1) -> int:
	var base_cost = item_data.cost
	
	if not shop_config:
		return base_cost
	
	var price = base_cost
	
	# Apply rarity multiplier
	if shop_config.rarity_price_multipliers.has(item_data.rarity):
		price = int(price * shop_config.rarity_price_multipliers[item_data.rarity])
	
	# Apply level scaling
	var level_multiplier = 1.0 + (shop_config.level_price_scaling * (current_level - 1))
	price = int(price * level_multiplier)
	
	# Apply global price modifier
	price = int(price * shop_config.base_price_multiplier)
	
	return price

func get_item_display_price(item_data, current_level: int = 1) -> String:
	var cost = calculate_item_cost(item_data, current_level)
	return str(cost) + " Gold"

# === SPECIAL PURCHASES ===

func get_tooth_clear_cost() -> int:
	return shop_config.clear_tooth_cost if shop_config else 10

func can_afford_tooth_clear() -> bool:
	return can_afford(get_tooth_clear_cost())

func purchase_tooth_clear() -> bool:
	var cost = get_tooth_clear_cost()
	if spend_money(cost, "tooth_clearing"):
		print("🦷 Tooth cleared for ", cost, " gold")
		return true
	return false

# === OWNERSHIP TRACKING ===

func is_artifact_owned(artifact_id: String) -> bool:
	for artifact in owned_artifacts:
		if artifact.id == artifact_id:
			return true
	return false

func can_artifact_evolve(artifact_data: ArtifactData) -> bool:
	if not artifact_data.can_evolve:
		return false
	
	return is_artifact_owned(artifact_data.id)

func get_owned_artifacts() -> Array[ArtifactData]:
	return owned_artifacts.duplicate()

func update_owned_artifacts(artifacts: Array[ArtifactData]):
	owned_artifacts = artifacts.duplicate()
	print("📦 Updated owned artifacts: ", owned_artifacts.size(), " items")

# === DISCOUNTS & SPECIAL OFFERS ===

func apply_discount(base_cost: int, discount_percent: float) -> int:
	var discounted = int(base_cost * (1.0 - discount_percent))
	return max(discounted, 1)  # Minimum 1 gold

func is_item_on_sale(item_data) -> bool:
	if not shop_config or not shop_config.enable_discounts:
		return false
	
	# Simple random chance for sales
	return randf() < shop_config.discount_chance

func get_sale_price(item_data, current_level: int = 1) -> int:
	var base_price = calculate_item_cost(item_data, current_level)
	
	if is_item_on_sale(item_data):
		return apply_discount(base_price, shop_config.discount_amount)
	
	return base_price

# === UTILITY ===

func get_money_display_text() -> String:
	return str(current_money) + " Gold"

func get_purchase_summary() -> Dictionary:
	return {
		"money": current_money,
		"owned_artifacts": owned_artifacts.size()
	}

# === DEBUG ===

func debug_purchase_state():
	print("=== PURCHASE HANDLER DEBUG ===")
	print("Current money: ", current_money)
	print("Owned artifacts: ", owned_artifacts.size())
	for artifact in owned_artifacts:
		print("  - ", artifact.name, " (Uses: ", artifact.uses_remaining, ")")

func add_debug_money(amount: int):
	current_money += amount
	emit_signal("money_changed", current_money)
	print("💰 Debug: Added ", amount, " gold (Total: ", current_money, ")")
