extends CanvasLayer

signal continue_pressed

func _ready():
	# Hide initially
	visible = false

func show_results(round_score, money_earned):
	# Update values
	$MidBar/ScoreContainer/ScoreValue.text = str(round_score)
	$MidBar/MoneyContainer/MoneyValue.text = str(money_earned)
	
	# Show the screen
	visible = true
	
	# Connect button if not already connected
	if not $BoxContainer/ContinueButton.is_connected("pressed", _on_continue_button_pressed):
		$BoxContainer/ContinueButton.pressed.connect(_on_continue_button_pressed)

func _on_continue_button_pressed():
	# Hide the screen
	visible = false
	
	# Emit signal to continue
	emit_signal("continue_pressed")
