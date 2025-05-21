extends CanvasLayer

signal continue_pressed

func _ready():
	# Hide initially
	visible = false

func show_results(round_score, money_earned, total_score = 0, target_score = 0):
	# Update values
	$MidBar/ScoreContainer/ScoreValue.text = str(round_score)
	$MidBar/MoneyContainer/MoneyValue.text = str(money_earned)
	
	# Add total score and target info if provided
	if total_score > 0:
		$MarginContainer/HBoxContainer/TotalScoreValue.text = str(total_score) + " / " + str(target_score)
	
	# Show the screen
	visible = true
	
	# Connect button if not already connected
	if not $BoxContainer/ContinueButton.is_connected("pressed", _on_continue_button_pressed):
		$BoxContainer/ContinueButton.pressed.connect(_on_continue_button_pressed)
	
	print("Showing round transition: Round score: ", round_score, 
		  " Money earned: ", money_earned,
		  " Total score: ", total_score,
		  " Target: ", target_score)

func _on_continue_button_pressed():
	# Hide the screen
	visible = false
	
	# Emit signal to continue
	emit_signal("continue_pressed")

func _input(event):
	# For debugging - toggle visibility with Tab key
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		if OS.is_debug_build():
			visible = !visible
			print("Transition visibility toggled: ", visible)
