class_name TattooData
extends Resource

@export var id: String
@export var name: String
@export var description: String
@export var cost: int
@export var multiplier: float = 1.0
@export var special_effect: String = ""
@export var icon_texture: Texture2D
@export var rarity: String = "common" # common, rare, epic

func _init(p_id = "", p_name = "", p_description = "", p_cost = 0, p_multiplier = 1.0):
	id = p_id
	name = p_name
	description = p_description
	cost = p_cost
	multiplier = p_multiplier
