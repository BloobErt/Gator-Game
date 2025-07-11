# ShopItemGenerator.gd
# Handles generation of shop inventory
extends Node

var shop_config: ShopConfig
var available_tattoos: Array[TattooData] = []
var available_artifacts: Array[ArtifactData] = []

func setup(config: ShopConfig):
	shop_config = config
	load_all_items()
	print("✅ ShopItemGenerator initialized")

func load_all_items():
	load_tattoo_pool()
	load_artifact_pool()

func load_tattoo_pool():
	available_tattoos.clear()
	
	var tattoo_folder = "res://Data/tattoos/"
	var dir = DirAccess.open(tattoo_folder)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path = tattoo_folder + file_name
				
				var tattoo_data = load(full_path) as TattooData
				if tattoo_data:
					available_tattoos.append(tattoo_data)
					print("✅ Loaded tattoo: ", tattoo_data.name)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
		print("Total tattoos loaded: ", available_tattoos.size())
	else:
		print("❌ Could not open tattoo directory: ", tattoo_folder)

func load_artifact_pool():
	available_artifacts.clear()
	
	var artifact_folder = "res://Data/artifacts/"
	var dir = DirAccess.open(artifact_folder)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path = artifact_folder + file_name
				
				var artifact_data = load(full_path) as ArtifactData
				if artifact_data:
					available_artifacts.append(artifact_data)
					print("✅ Loaded artifact: ", artifact_data.name)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
		print("Total artifacts loaded: ", available_artifacts.size())
	else:
		print("❌ Could not open artifact directory: ", artifact_folder)

# === GENERATION METHODS ===

func generate_tattoo_selection() -> Array[TattooData]:
	var selection: Array[TattooData] = []
	
	var shuffled_tattoos: Array[TattooData] = []
	shuffled_tattoos.assign(available_tattoos)
	shuffled_tattoos.shuffle()
	
	var slot_count = shop_config.tattoo_slots if shop_config else 5
	
	for i in range(min(slot_count, shuffled_tattoos.size())):
		selection.append(shuffled_tattoos[i])
	
	print("Generated ", selection.size(), " tattoos for shop")
	return selection

func generate_artifact_selection() -> Array[ArtifactData]:
	var selection: Array[ArtifactData] = []
	
	var shuffled_artifacts: Array[ArtifactData] = []
	shuffled_artifacts.assign(available_artifacts)
	shuffled_artifacts.shuffle()
	
	var slot_count = shop_config.artifact_slots if shop_config else 3
	
	for i in range(min(slot_count, shuffled_artifacts.size())):
		selection.append(shuffled_artifacts[i])
	
	print("Generated ", selection.size(), " artifacts for shop")
	return selection

func get_item_price(item_data, item_type: String, current_level: int = 1) -> int:
	var base_cost = item_data.cost
	
	if not shop_config:
		return base_cost
	
	# Apply rarity multiplier
	var rarity_multiplier = 1.0
	if shop_config.rarity_price_multipliers.has(item_data.rarity):
		rarity_multiplier = shop_config.rarity_price_multipliers[item_data.rarity]
	
	# Apply level scaling
	var level_multiplier = 1.0 + (shop_config.level_price_scaling * (current_level - 1))
	
	# Calculate final price
	var final_price = int(base_cost * rarity_multiplier * level_multiplier * shop_config.base_price_multiplier)
	
	return final_price

func get_available_tattoos() -> Array[TattooData]:
	return available_tattoos.duplicate()

func get_available_artifacts() -> Array[ArtifactData]:
	return available_artifacts.duplicate()

# === FILTERING (for future level-based availability) ===

func get_tattoos_for_level(level: int) -> Array[TattooData]:
	# Future: Filter tattoos based on level availability
	return available_tattoos.duplicate()

func get_artifacts_for_level(level: int) -> Array[ArtifactData]:
	# Future: Filter artifacts based on level availability  
	return available_artifacts.duplicate()

# === DEBUG ===

func debug_available_items():
	print("=== ITEM GENERATOR DEBUG ===")
	print("Available tattoos: ", available_tattoos.size())
	for tattoo in available_tattoos:
		print("  - ", tattoo.name, " (", tattoo.rarity, ")")
	
	print("Available artifacts: ", available_artifacts.size())
	for artifact in available_artifacts:
		print("  - ", artifact.name, " (", artifact.rarity, ")")

func reload_items():
	"""Reload all items from disk (useful for development)"""
	load_all_items()
	print("🔄 Reloaded all shop items")
