extends CanvasLayer

signal shop_closed(teeth_tattoo_mapping)

var available_tattoos: Array[TattooData] = []
var available_artifacts: Array[ArtifactData] = []
var player_money: int = 0
var teeth_slots: Array = []  # Array of ToothSlot nodes
var purchased_artifacts: Array[ArtifactData] = []

@onready var money_label = $ShopContainer/MoneyDisplay/MoneyLabel
@onready var tattoo_slots = [$ShopContainer/TattooSection/TattooContainer/TattooSlot1,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot2,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot3,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot4,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot5]
@onready var artifact_slots = [$ShopContainer/ArtifactSection/ArtifactContainer/ArtifactSlot1,
							   $ShopContainer/ArtifactSection/ArtifactContainer/ArtifactSlot2,
							   $ShopContainer/ArtifactSection/ArtifactContainer/ArtifactSlot3]
@onready var teeth_grid = $ShopContainer/TeethSection/TeethGrid
@onready var exit_button = $ShopContainer/ExitButton
@onready var clear_tooth_button = $ShopContainer/UtilitySection/ClearToothButton

func _ready():
	exit_button.pressed.connect(_on_exit_pressed)
	clear_tooth_button.pressed.connect(_on_clear_tooth_pressed)
	
	generate_tattoo_pool()
	generate_artifact_pool()
	setup_teeth_grid()

func open_shop(money: int):
	player_money = money
	update_money_display()
	generate_shop_items()
	visible = true

func generate_tattoo_pool():
	# Create different types of tattoos
	var tattoo_pool = [
		TattooData.new("mult_2x", "2x Multiplier", "Doubles tooth value", 50, 2.0),
		TattooData.new("mult_3x", "3x Multiplier", "Triples tooth value", 100, 3.0),
		TattooData.new("bonus_10", "+10 Bonus", "Adds 10 to tooth value", 30, 1.0),
		TattooData.new("bonus_20", "+20 Bonus", "Adds 20 to tooth value", 60, 1.0),
		TattooData.new("lucky", "Lucky Tooth", "Small chance for 5x value", 80, 1.0),
		TattooData.new("safe", "Safe Bet", "Never the bite tooth", 150, 1.0),
		TattooData.new("mult_4x", "4x Multiplier", "Quadruples tooth value", 200, 4.0),
	]
	
	available_tattoos = tattoo_pool

func generate_artifact_pool():
	# Create artifacts (these are purchased directly, not dragged)
	var artifact_pool = [
		ArtifactData.new("steady_hand", "Steady Hand", "After 3 teeth, 1.2x multiplier", 150),
		ArtifactData.new("risk_taker", "Risk Taker", "After 5 teeth, 1.5x multiplier", 200),
		ArtifactData.new("early_bird", "Early Bird", "First tooth has 2x value", 120),
		ArtifactData.new("lucky_streak", "Lucky Streak", "Chain bonus for consecutive teeth", 180),
		ArtifactData.new("safety_net", "Safety Net", "Reduced bite penalty", 100),
	]

func generate_shop_items():
	# Randomly select 5 tattoos for the shop
	var shuffled_tattoos = available_tattoos.duplicate()
	shuffled_tattoos.shuffle()
	
	for i in range(min(5, tattoo_slots.size())):
		if i < shuffled_tattoos.size():
			tattoo_slots[i].setup_tattoo(shuffled_tattoos[i])
			tattoo_slots[i].tattoo_dragged.connect(_on_tattoo_dragged)
	
	# Generate artifacts (implement artifact setup when you create ArtifactShopItem script)

func setup_teeth_grid():
	# Create 16 tooth slots (representing potential teeth combinations)
	teeth_grid.columns = 4
	
	for i in range(16):  # 16 slots, each can become any random tooth
		var tooth_slot = preload("res://Scenes/tooth_slot.tscn").instantiate()
		tooth_slot.setup_slot(i)
		tooth_slot.tattoo_applied.connect(_on_tattoo_applied_to_slot)
		teeth_grid.add_child(tooth_slot)
		teeth_slots.append(tooth_slot)

func _on_tattoo_applied_to_slot(slot_index: int, tattoo_data: TattooData):
	if player_money >= tattoo_data.cost:
		# Deduct money
		player_money -= tattoo_data.cost
		update_money_display()
		
		print("Applied ", tattoo_data.name, " to slot ", slot_index)
	else:
		print("Not enough money!")
		# Remove the tattoo from the slot since purchase failed
		teeth_slots[slot_index].applied_tattoos.pop_back()
		teeth_slots[slot_index].tattoo_container.get_child(-1).queue_free()

func create_random_tooth_mapping():
	# Create mapping from shop slots to actual game teeth
	var game_tooth_names = ["Left", "MidLeft", "MidRight", "Right", 
						   "LeftD", "RightD",
						   "L1", "L2", "L3", "L4", "L5",
						   "R1", "R2", "R3", "R4", "R5"]
	
	var tooth_mapping = {}
	
	for i in range(teeth_slots.size()):
		var slot = teeth_slots[i]
		if slot.applied_tattoos.size() > 0:
			# Randomly assign this slot's tattoos to a game tooth
			var random_tooth = game_tooth_names[randi() % game_tooth_names.size()]
			tooth_mapping[random_tooth] = slot.applied_tattoos.duplicate()
			
			print("Slot ", i, " with ", slot.applied_tattoos.size(), " tattoos assigned to tooth: ", random_tooth)
	
	return tooth_mapping

func update_money_display():
	money_label.text = "Money: " + str(player_money)

func _on_clear_tooth_pressed():
	# Allow player to clear a slot for money
	print("Clear tooth feature - select a slot to clear")
	# You could implement a selection mode here

func _on_exit_pressed():
	visible = false
	var final_mapping = create_random_tooth_mapping()
	emit_signal("shop_closed", final_mapping)

func _on_tattoo_dragged(tattoo_data: TattooData, source_control):
	# Visual feedback for dragging
	pass
