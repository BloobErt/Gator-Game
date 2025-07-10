# ProgressionManager.gd
# Handles level progression, round management, and scoring logic
extends Node

signal level_completed(level_number: int, score: int)
signal round_completed(round_number: int, score: int)

var game_config: GameConfig
var level_data: Array[LevelData] = []
var current_round: int = 1

func setup(config: GameConfig, levels: Array[LevelData]):
	game_config = config
	level_data = levels
	print("✅ ProgressionManager initialized with ", level_data.size(), " levels")

func get_current_round() -> int:
	return current_round

func advance_round():
	current_round += 1
	if current_round > game_config.max_rounds_per_level:
		current_round = 1  # Reset for next level

func is_level_complete(total_score: int, target_score: int) -> bool:
	return total_score >= target_score

func is_game_complete(current_level: int) -> bool:
	return current_level >= game_config.max_levels

func get_level_data(level_number: int) -> LevelData:
	if level_number > 0 and level_number <= level_data.size():
		return level_data[level_number - 1]
	return null

func calculate_level_progress(current_score: int, target_score: int) -> float:
	return float(current_score) / float(target_score)

func get_completion_rank(score: int, level_data: LevelData) -> String:
	if score >= level_data.perfect_score_threshold:
		return "Perfect"
	elif score >= level_data.bonus_score_threshold:
		return "Excellent"
	elif score >= level_data.target_score:
		return "Complete"
	else:
		return "Incomplete"

func should_show_completion_bonus(score: int, level_data: LevelData) -> bool:
	return score >= level_data.bonus_score_threshold
