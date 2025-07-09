# ShopConfig.gd
# Configuration for shop generation and behavior
class_name ShopConfig
extends Resource

# Shop Layout
@export_group("Shop Setup")
@export var tattoo_slots: int = 5
@export var artifact_slots: int = 3
@export var enable_tooth_clearing: bool = true
@export var clear_tooth_cost: int = 10

# Generation Rules
@export_group("Item Generation")
@export var tattoo_rarity_weights: Dictionary = {
	"common": 60,
	"rare": 30,
	"epic": 9,
	"legendary": 1
}
@export var artifact_rarity_weights: Dictionary = {
	"common": 40,
	"rare": 45,
	"epic": 13,
	"legendary": 2
}

# Price Modifiers
@export_group("Pricing")
@export var base_price_multiplier: float = 1.0
@export var level_price_scaling: float = 0.1  # 10% more expensive per level
@export var rarity_price_multipliers: Dictionary = {
	"common": 1.0,
	"rare": 2.0,
	"epic": 4.0,
	"legendary": 8.0
}

# Shop Pools
@export_group("Available Items")
@export var available_tattoo_pools: Dictionary = {
	1: ["1", "2", "4"],  # level 1 available tattoos
	2: ["1", "2", "3", "4"],  # level 2, etc.
	3: ["1", "2", "3", "4", "5"]
}
@export var available_artifact_pools: Dictionary = {
	1: ["tooth_modifier", "2"],
	2: ["tooth_modifier", "2", "3"],
	3: ["tooth_modifier", "2", "3", "safe_tooth_revealer"]
}

# Refresh Settings
@export_group("Shop Refresh")
@export var enable_refresh: bool = false  # for future feature
@export var refresh_cost: int = 5
@export var free_refreshes_per_level: int = 1

# Special Offers
@export_group("Special Mechanics")
@export var enable_discounts: bool = true
@export var discount_chance: float = 0.1  # 10% chance per item
@export var discount_amount: float = 0.25  # 25% off
@export var enable_bundles: bool = false  # future feature
