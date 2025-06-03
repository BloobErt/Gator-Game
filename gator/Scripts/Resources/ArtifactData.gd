class_name ArtifactData
extends Resource

@export var id: String
@export var name: String
@export var description: String
@export var cost: int
@export var icon_texture: Texture2D
@export var rarity: String = "rare"

# Effect configuration
@export_group("Effect Settings")
@export var effect_type: String = "passive" # passive, active, trigger, persistent, evolving
@export var effect_data: Dictionary = {} # For complex effects
@export var is_active_artifact: bool = false # Can be manually activated
@export var uses_remaining: int = -1 # -1 = unlimited uses
@export var max_uses: int = -1 # For artifacts with limited uses

# Evolution system
@export var can_evolve: bool = false
@export var evolved_form: ArtifactData = null
@export var evolution_condition: String = "" # "buy_duplicate", "use_x_times", etc.

func _init(p_id = "", p_name = "", p_description = "", p_cost = 0):
	id = p_id
	name = p_name
	description = p_description
	cost = p_cost

# Apply passive effects (called during tooth press)
func apply_passive_effect(tooth_name: String, base_value: int, base_multiplier: float, game_state: Dictionary) -> Dictionary:
	var result = {
		"value": base_value,
		"multiplier": base_multiplier,
		"special_effects": [],
		"persistent_effects": []
	}
	
	if effect_type != "passive":
		return result
	
	match id:
		"2":
			var teeth_pressed = game_state.get("teeth_pressed_count", 0)
			if teeth_pressed == 1:
				result.multiplier *= 3.0
				result.special_effects.append("First Tooth Bonus! 3x multiplier!")
		
		"6":
			var teeth_pressed = game_state.get("teeth_pressed_count", 0)
			var bonus = teeth_pressed * 2
			result.value += bonus
			result.special_effects.append("Accumulator: +" + str(bonus) + " value!")
		
		"7":
			var teeth_pressed = game_state.get("teeth_pressed_count", 0)
			if teeth_pressed == 5:
				# Add value of all previous teeth pressed this round
				var previous_teeth_value = game_state.get("round_score", 0)
				result.value += previous_teeth_value
				result.special_effects.append("Evolved Accumulator: +" + str(previous_teeth_value) + " from previous teeth!")
			else:
				# Normal accumulator effect
				var bonus = teeth_pressed * 2
				result.value += bonus
				result.special_effects.append("Accumulator: +" + str(bonus) + " value!")
		
		"odd_tooth_booster":
			var teeth_pressed = game_state.get("teeth_pressed_count", 0)
			if teeth_pressed % 2 == 1: # Odd teeth (1st, 3rd, 5th, etc.)
				result.value += 40
				result.special_effects.append("Odd Tooth Boost: +40 value!")
	
	return result

# Apply trigger effects (called on specific events)
func apply_trigger_effect(trigger_type: String, game_state: Dictionary) -> Dictionary:
	var result = {
		"special_effects": [],
		"persistent_effects": [],
		"can_continue": true # For bite tooth effects
	}
	
	if effect_type != "trigger":
		return result
	
	match trigger_type:
		"bite_tooth_hit":
			if id == "3":
				result.can_continue = true
				result.special_effects.append("Bite Survivor activated! You can continue pressing teeth!")
				
				# Reduce remaining uses
				if uses_remaining > 0:
					uses_remaining -= 1
					if uses_remaining == 0:
						result.special_effects.append("Bite Survivor exhausted!")
	
	return result

# Apply active effects (called when player manually activates)
func apply_active_effect(target_tooth: String, game_state: Dictionary) -> Dictionary:
	var result = {
		"success": false,
		"special_effects": [],
		"persistent_effects": []
	}
	
	if not is_active_artifact or uses_remaining == 0:
		return result
	
	match id:
		"tooth_modifier":
			# Check if target tooth has no tattoos
			var tooth_tattoos = game_state.get("tooth_tattoos", {})
			if not tooth_tattoos.has(target_tooth) or tooth_tattoos[target_tooth].size() == 0:
				result.success = true
				result.persistent_effects.append({
					"type": "modify_tooth",
					"tooth_name": target_tooth,
					"value_multiplier": 0.5,
					"max_tattoos": 5
				})
				result.special_effects.append("Tooth modified: Half value, 5 tattoo slots!")
				
				# Use up one charge
				if uses_remaining > 0:
					uses_remaining -= 1
			else:
				result.special_effects.append("Cannot use on tooth with tattoos!")
		
		"safe_tooth_revealer":
			result.success = true
			result.persistent_effects.append({
				"type": "reveal_safe_teeth",
				"count": 3
			})
			result.special_effects.append("Revealing 3 safe teeth!")
			
			# Single use artifact
			if uses_remaining > 0:
				uses_remaining -= 1
	
	return result

# Apply persistent effects (called at round start or game state changes)
func apply_persistent_effect(game_state: Dictionary) -> Dictionary:
	var result = {
		"special_effects": [],
		"game_modifications": []
	}
	
	if effect_type != "persistent":
		return result
	
	match id:
		"round_reducer":
			result.game_modifications.append({
				"type": "set_max_rounds",
				"value": 4
			})
			result.special_effects.append("Round limit reduced to 4!")
	
	return result

# Check if artifact can evolve
func can_evolve_now(owned_artifacts: Array) -> bool:
	if not can_evolve or evolved_form == null:
		return false
	
	match evolution_condition:
		"buy_duplicate":
			# Count how many of this artifact we own
			var count = 0
			for artifact in owned_artifacts:
				if artifact.id == id:
					count += 1
			return count >= 2
		
		"use_depleted":
			return max_uses > 0 and uses_remaining <= 0
	
	return false

# Evolve this artifact
func evolve() -> ArtifactData:
	if can_evolve and evolved_form:
		return evolved_form
	return self

# Reset uses (for new rounds/levels)
func reset_uses():
	if max_uses > 0:
		uses_remaining = max_uses
