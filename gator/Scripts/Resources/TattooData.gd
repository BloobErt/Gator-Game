class_name TattooData
extends Resource

@export var id: String
@export var name: String
@export var description: String
@export var cost: int
@export var icon_texture: Texture2D
@export var rarity: String = "common" # common, rare, epic, legendary

# Effect configuration
@export_group("Effect Settings")
@export var effect_type: String = "simple_multiplier" # simple_multiplier, bonus, conditional, persistent, curse
@export var effect_value: float = 1.0
@export var effect_data: Dictionary = {} # For complex effects

func _init(p_id = "", p_name = "", p_description = "", p_cost = 0):
	id = p_id
	name = p_name
	description = p_description
	cost = p_cost

# Apply the tattoo effect to a tooth press
func apply_effect(tooth_name: String, base_value: int, base_multiplier: float, game_state: Dictionary) -> Dictionary:
	var result = {
		"value": base_value,
		"multiplier": base_multiplier,
		"special_effects": [],
		"persistent_effects": []
	}
	
	match effect_type:
		"simple_multiplier":
			result.multiplier *= effect_value
			
		"bonus":
			result.value += int(effect_value)
			
		"lucky":
			var chance = effect_data.get("chance", 0.1)
			var lucky_multiplier = effect_data.get("lucky_multiplier", 5.0)
			if randf() < chance:
				result.multiplier *= lucky_multiplier
				result.special_effects.append("Lucky hit! " + str(lucky_multiplier) + "x multiplier!")
				
		"safe":
			result.special_effects.append("This tooth is protected from being the bite tooth")
			
		"high_value_no_growth":
			# Set very high value but prevent growth
			result.value = int(effect_data.get("fixed_value", effect_value))
			result.special_effects.append("Fixed high value - cannot be modified by other effects")
			
		"lucky_thirteen":
			# Special effect: if 7th tooth pressed AND bite tooth = 13,000 points
			var teeth_pressed = game_state.get("teeth_pressed_count", 0)
			var is_bite_tooth = game_state.get("is_bite_tooth", false)
			if teeth_pressed == 7 and is_bite_tooth:
				result.value = 13000
				result.multiplier = 1.0
				result.special_effects.append("LUCKY THIRTEEN! 13,000 points!")
				
		"skip_next_round":
			# Triple value but make tooth unusable next round
			result.multiplier *= effect_value
			result.persistent_effects.append({
				"type": "disable_next_round",
				"tooth_name": tooth_name
			})
			result.special_effects.append("Tripled value but tooth disabled next round!")
			
		"double_points_add_bite":
			# Double all future points but add another bite tooth
			result.persistent_effects.append({
				"type": "global_multiplier",
				"multiplier": 2.0,
				"description": "All points doubled!"
			})
			result.persistent_effects.append({
				"type": "add_bite_tooth",
				"description": "Added another bite tooth!"
			})
			result.special_effects.append("All future points doubled, but beware - another bite tooth added!")
			
		"conditional":
			# Generic conditional effect system
			var condition = effect_data.get("condition", "")
			var condition_value = effect_data.get("condition_value", 0)
			var meets_condition = check_condition(condition, condition_value, game_state)
			
			if meets_condition:
				result.multiplier *= effect_data.get("success_multiplier", 1.0)
				result.value += int(effect_data.get("success_bonus", 0))
				result.special_effects.append(effect_data.get("success_message", "Condition met!"))
			else:
				result.multiplier *= effect_data.get("failure_multiplier", 1.0)
				result.value += int(effect_data.get("failure_bonus", 0))
				if effect_data.has("failure_message"):
					result.special_effects.append(effect_data.get("failure_message", ""))
	
	return result

# Check various conditions for conditional effects
func check_condition(condition: String, value: float, game_state: Dictionary) -> bool:
	match condition:
		"teeth_pressed_equals":
			return game_state.get("teeth_pressed_count", 0) == value
		"teeth_pressed_greater":
			return game_state.get("teeth_pressed_count", 0) > value
		"round_number_equals":
			return game_state.get("current_round", 1) == value
		"is_first_tooth":
			return game_state.get("teeth_pressed_count", 0) == 1
		"is_last_safe_tooth":
			var safe_teeth_remaining = game_state.get("safe_teeth_remaining", 0)
			return safe_teeth_remaining == 1
		"random_chance":
			return randf() < value
		_:
			return false

# Check if this tattoo affects bite tooth selection
func affects_bite_selection() -> bool:
	return effect_type == "safe" or id == "safe"

# Check if this tattoo has persistent effects that carry over
func has_persistent_effects() -> bool:
	return effect_type in ["double_points_add_bite", "skip_next_round"]
