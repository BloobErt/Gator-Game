# LevelData.gd
# Configuration for individual levels
class_name LevelData
extends Resource

@export var level_number: int = 1
@export var display_name: String = "Level 1"

# Scoring
@export_group("Scoring")
@export var target_score: int = 100
@export var bonus_score_threshold: int = 150  # extra rewards above this
@export var perfect_score_threshold: int = 200

# Difficulty
@export_group("Difficulty")
@export var tooth_value_min: int = 5
@export var tooth_value_max: int = 15
@export var num_multiplier_teeth: int = 2
@export var multiplier_values: Array[float] = [2.0, 2.0]  # can have different multipliers
@export var bite_tooth_count: int = 1  # some levels might have multiple bite teeth

# Special Rules
@export_group("Special Mechanics")
@export var special_rules: Array[String] = []  # e.g., ["no_safe_tattoos", "double_bite_teeth"]
@export var starting_artifacts: Array[String] = []  # artifact IDs to give at level start
@export var unlocked_tattoo_types: Array[String] = ["common"]  # tattoo rarities available
@export var unlocked_artifact_types: Array[String] = ["common", "rare"]

# Visual Theme
@export_group("Presentation")
@export var background_theme: String = "swamp"  # for future theming
@export var level_description: String = "Click teeth to score points, but avoid the bite tooth!"
@export var completion_message: String = "Well done! Moving to the next level."

# Rewards
@export_group("Rewards")
@export var completion_money_bonus: int = 50
@export var perfect_completion_bonus: int = 100
@export var unlocks_on_completion: Array[String] = []  # new content unlocked
