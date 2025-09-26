# EconomyManager.gd
# Handles all money, costs, and economic calculations
extends Node

signal shop_transaction(cost: int, item_type: String)
signal money_changed(new_amount: int)

var game_config: GameConfig
var shop_config: ShopConfig
var current_money: int = 0

func setup(config: GameConfig, shop_cfg: ShopConfig):
	game_config = config
	shop_config = shop_cfg
	current_money = 0  # Could load from save file
	print("✅ EconomyManager initialized")

func get_current_money() -> int:
	return current_money

func can_afford(cost: int) -> bool:
	return current_money >= cost

func spend_money(amount: int, item_type: String = "") -> bool:
	if can_afford(amount):
		current_money -= amount
		emit_signal("shop_transaction", amount, item_type)
		emit_signal("money_changed", current_money)
		print("💰 Spent ", amount, " gold on ", item_type, " (Remaining: ", current_money, ")")
		return true
	else:
		print("❌ Cannot afford ", amount, " gold (Have: ", current_money, ")")
		return false

func add_money(amount: int, source: String = ""):
	current_money += amount
	emit_signal("money_changed", current_money)
	print("💰 Earned ", amount, " gold from ", source, " (Total: ", current_money, ")")

func calculate_round_money(round_score: int) -> int:
	return int(round_score * game_config.money_conversion_rate)

func award_round_money(round_score: int):
	var money_earned = calculate_round_money(round_score)
	add_money(money_earned, "round completion")

func award_completion_bonus(bonus_amount: int):
	add_money(bonus_amount, "level completion bonus")

func calculate_item_price(base_cost: int, rarity: String, current_level: int) -> int:
	var price = base_cost
	
	# Apply rarity multiplier
	if shop_config.rarity_price_multipliers.has(rarity):
		price = int(price * shop_config.rarity_price_multipliers[rarity])
	
	# Apply level scaling
	var level_multiplier = 1.0 + (shop_config.level_price_scaling * (current_level - 1))
	price = int(price * level_multiplier)
	
	# Apply global price modifier
	price = int(price * shop_config.base_price_multiplier)
	
	return price

func get_clear_tooth_cost() -> int:
	return shop_config.clear_tooth_cost

func can_clear_tooth() -> bool:
	return can_afford(get_clear_tooth_cost())

func clear_tooth() -> bool:
	return spend_money(get_clear_tooth_cost(), "tooth clearing")

# Debug function
func add_debug_money(amount: int):
	if game_config and game_config.debug_mode:
		add_money(amount, "debug")

func get_money_display_text() -> String:
	return str(current_money) + " Gold"

# Save/Load functions for future
func save_economy_data() -> Dictionary:
	return {
		"money": current_money
	}

func load_economy_data(data: Dictionary):
	if data.has("money"):
		current_money = data.money
		emit_signal("money_changed", current_money)
