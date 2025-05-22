extends CanvasLayer

signal shop_closed(teeth_tattoos)

var available_tattoos: Array[TattooData] = []
var available_artifacts: Array[ArtifactData] = []
var player_money: int = 0
var teeth_tattoos: Dictionary = {}

@onready var money_label = $ShopContainer/MoneyDisplay/MoneyLabel
@onready var tattoo_slots = [$ShopContainer/TattooSection/TattooContainer/TattooSlot1,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot2,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot3,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot4,
							 $ShopContainer/TattooSection/TattooContainer/TattooSlot5]
@onready var teeth_grid = $ShopContainer/TeethSection/TeethGrid
@onready var exit_button = $ShopContainer/ExitButton
@onready var clear_tooth_button = $ShopContainer/ClearToothButton

func _ready():
	exit_button.pressed.connect(_on_exit_pressed)
	clear_tooth_button.pressed.connect(_on_clear_tooth_pressed)
	
	generate_tattoo_pool()
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
	]
	
	available_tattoos = tattoo_pool

func generate_shop_items():
	# Randomly select 5 tattoos for the shop
	var shuffled_tattoos = available_tattoos.duplicate()
	shuffled_tattoos.shuffle()
	
	for i in range(min(5, tattoo_slots.size())):
		if i < shuffled_tattoos.size():
			tattoo_slots[i].setup_tattoo(shuffled_tattoos[i])
			tattoo_slots[i].tattoo_dragged.connect(_on_tattoo_dragged)

func setup_teeth_grid():
	# Create 16 tooth slots (4x4 grid)
	teeth_grid.columns = 4
	
	var tooth_names = ["Front_Left", "Front_MidLeft", "Front_MidRight", "Front_Right",
					  "Side_L1", "Side_L2", "Side_L3", "Side_L4",
					  "Side_R1", "Side_R2", "Side_R3", "Side_R4", 
					  "Diag_Left", "Diag_Right", "Extra_1", "Extra_2"]
	
	for tooth_name in tooth_names:
		var tooth_slot = preload("res://Scenes/tooth_slot.tscn").instantiate()
		tooth_slot.setup_tooth(tooth_name)
		tooth_slot.tattoo_applied.connect(_on_tattoo_applied)
		teeth_grid.add_child(tooth_slot)

func _on_tattoo_dragged(tattoo_data: TattooData, source_control):
	# Handle tattoo being dragged (visual feedback, etc.)
	pass

func _on_tattoo_applied(tooth_name: String, tattoo_data: TattooData):
	if player_money >= tattoo_data.cost:
		# Deduct money
		player_money -= tattoo_data.cost
		update_money_display()
		
		# Store the tattoo application
		if not teeth_tattoos.has(tooth_name):
			teeth_tattoos[tooth_name] = []
		teeth_tattoos[tooth_name].append(tattoo_data)
		
		print("Applied ", tattoo_data.name, " to ", tooth_name)
	else:
		print("Not enough money!")
		# Remove the tattoo from the tooth since purchase failed
		# You'll need to implement this rollback

func update_money_display():
	money_label.text = "Money: " + str(player_money)

func _on_clear_tooth_pressed():
	# Implement clear tooth functionality
	print("Clear tooth feature - to be implemented")

func _on_exit_pressed():
	visible = false
	emit_signal("shop_closed", teeth_tattoos)
