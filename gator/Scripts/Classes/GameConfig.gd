# GameConfig.gd
# Main game configuration - replace all magic numbers in your code
class_name GameConfig
extends Resource

# Core Game Settings
@export_group("Level Progression")
@export var max_rounds_per_level: int = 5
@export var base_score_target: int = 100
@export var score_multiplier_per_level: float = 1.5
@export var max_levels: int = 10

# Economy Settings
@export_group("Economy")
@export var money_conversion_rate: float = 0.1  # score to money conversion
@export var clear_tooth_cost: int = 10
@export var shop_refresh_cost: int = 5

# Tooth System
@export_group("Teeth Configuration")
@export var default_max_tattoos_per_tooth: int = 3
@export var base_tooth_value_min: int = 5
@export var base_tooth_value_max: int = 15
@export var tooth_value_level_multiplier: float = 1.0
@export var multiplier_tooth_chance: float = 0.3
@export var default_multiplier_value: float = 2.0

# Round Settings
@export_group("Round Mechanics")
@export var bite_penalty_percentage: float = 0.05
@export var end_round_button_delay: float = 2.0  # seconds after bite

# Shop Settings
@export_group("Shop Configuration")
@export var tattoo_slots_in_shop: int = 5
@export var artifact_slots_in_shop: int = 3
@export var shop_drawer_animation_speed: float = 0.6

# UI Settings
@export_group("User Interface")
@export var score_popup_duration: float = 1.0
@export var tooltip_show_delay: float = 0.1
@export var transition_fade_time: float = 0.5

# Audio Settings
@export_group("Audio")
@export var master_volume: float = 1.0
@export var sfx_volume: float = 0.8
@export var music_volume: float = 0.6
@export var ui_volume: float = 0.7

# Debug Settings
@export_group("Debug")
@export var debug_mode: bool = false
@export var show_fps: bool = false
@export var unlimited_money: bool = false
