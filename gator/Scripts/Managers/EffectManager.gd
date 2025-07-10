# EffectManager.gd
# Manages artifacts, special effects, and game modifiers
extends Node

var game_config: GameConfig
var ui_config: UIConfig
var owned_artifacts: Array[ArtifactData] = []
var active_modifiers: Dictionary = {}

func setup(config: GameConfig, ui_cfg: UIConfig):
	game_config = config
	ui_config = ui_cfg
	print("✅ EffectManager initialized")

func add_artifacts(new_artifacts: Array[ArtifactData]):
	for artifact in new_artifacts:
		add_artifact(artifact)

func add_artifact(artifact: ArtifactData):
	# Check for evolution
	if artifact.can_evolve_now(owned_artifacts):
		var evolved = artifact.evolve()
		owned_artifacts.append(evolved)
		print("🔮 Artifact evolved to: ", evolved.name)
	else:
		owned_artifacts.append(artifact)
		print("📦 Added artifact: ", artifact.name)
	
	# Apply any immediate effects
	apply_artifact_immediate_effects(artifact)

func apply_artifact_immediate_effects(artifact: ArtifactData):
	# Handle artifacts that have immediate effects when acquired
	match artifact.effect_type:
		"persistent":
			apply_persistent_artifact_effect(artifact)

func apply_persistent_artifact_effect(artifact: ArtifactData):
	var game_state = create_current_game_state()
	var result = artifact.apply_persistent_effect(game_state)
	
	for effect in result.special_effects:
		print("🔄 Persistent Effect: ", effect)
	
	for modification in result.game_modifications:
		apply_game_modification(modification)

func apply_game_modification(modification: Dictionary):
	match modification.type:
		"set_max_rounds":
			# Signal to game manager to change max rounds
			print("⚰️ Game modification: Max rounds = ", modification.value)
			active_modifiers["max_rounds"] = modification.value

func handle_bite_survival() -> bool:
	# Check all trigger artifacts for bite survival
	for artifact in owned_artifacts:
		if artifact.effect_type == "trigger" and artifact.uses_remaining > 0:
			var game_state = create_current_game_state()
			var result = artifact.apply_trigger_effect("bite_tooth_hit", game_state)
			
			if result.can_continue:
				# Consume the artifact use
				artifact.uses_remaining -= 1
				
				for effect in result.special_effects:
					print("🎯 Bite Survival: ", effect)
				
				return true
	
	return false

func use_active_artifact(artifact_id: String, target: String = "") -> bool:
	for artifact in owned_artifacts:
		if artifact.id == artifact_id and artifact.is_active_artifact:
			if artifact.uses_remaining > 0:
				var game_state = create_current_game_state()
				var result = artifact.apply_active_effect(target, game_state)
				
				if result.success:
					artifact.uses_remaining -= 1
					
					# Apply persistent effects
					for effect in result.persistent_effects:
						apply_artifact_persistent_effect_dict(effect)
					
					# Show special effects
					for effect in result.special_effects:
						print("⚡ Active Artifact: ", effect)
					
					return true
				else:
					for effect in result.special_effects:
						print("❌ Artifact Failed: ", effect)
			else:
				print("❌ No uses remaining for ", artifact.name)
			
			return false
	
	print("❌ Artifact not found: ", artifact_id)
	return false

func apply_artifact_persistent_effect_dict(effect: Dictionary):
	match effect.type:
		"modify_tooth":
			# Signal to tooth manager or game manager
			print("🔧 Tooth modification: ", effect)
		"reveal_safe_teeth":
			# Signal to create safe tooth indicators
			print("👁️ Revealing safe teeth: ", effect.count)
		"set_max_rounds":
			active_modifiers["max_rounds"] = effect.value

func get_active_artifacts() -> Array[ArtifactData]:
	var active: Array[ArtifactData] = []
	
	for artifact in owned_artifacts:
		if artifact.is_active_artifact and artifact.uses_remaining > 0:
			active.append(artifact)
	
	return active

func get_all_owned_artifacts() -> Array[ArtifactData]:
	return owned_artifacts.duplicate()

func apply_passive_effects_to_tooth(tooth_name: String, base_value: int, base_multiplier: float) -> Dictionary:
	var result = {
		"value": base_value,
		"multiplier": base_multiplier,
		"special_effects": []
	}
	
	var game_state = create_current_game_state()
	
	for artifact in owned_artifacts:
		if artifact.effect_type == "passive":
			var effect = artifact.apply_passive_effect(tooth_name, result.value, result.multiplier, game_state)
			result.value = effect.value
			result.multiplier = effect.multiplier
			result.special_effects.append_array(effect.special_effects)
	
	return result

func create_current_game_state() -> Dictionary:
	# This would ideally get current state from game manager
	# For now, return basic state
	return {
		"teeth_pressed_count": 1,
		"current_round": 1,
		"is_bite_tooth": false,
		"round_score": 0,
		"total_score": 0
	}

func has_artifact(artifact_id: String) -> bool:
	for artifact in owned_artifacts:
		if artifact.id == artifact_id:
			return true
	return false

func get_artifact_by_id(artifact_id: String) -> ArtifactData:
	for artifact in owned_artifacts:
		if artifact.id == artifact_id:
			return artifact
	return null

func get_modifier(modifier_name: String):
	return active_modifiers.get(modifier_name, null)

func clear_modifiers():
	active_modifiers.clear()

# Debug functions
func debug_print_artifacts():
	if game_config and game_config.debug_mode:
		print("=== ARTIFACT DEBUG ===")
		print("Owned artifacts: ", owned_artifacts.size())
		for artifact in owned_artifacts:
			print("- ", artifact.name, " (Uses: ", artifact.uses_remaining, ")")
		print("Active modifiers: ", active_modifiers)
