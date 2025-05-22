class_name ArtifactData
extends Resource

@export var id: String
@export var name: String
@export var description: String
@export var cost: int
@export var effect_type: String
@export var effect_value: float
@export var icon_texture: Texture2D
@export var rarity: String = "rare"

func _init(p_id = "", p_name = "", p_description = "", p_cost = 0):
	id = p_id
	name = p_name
	description = p_description
	cost = p_cost
