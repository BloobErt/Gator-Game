extends CanvasLayer

# UI References
@onready var score_value = $TopBar/MarginContainer/ScoreContainer/ScoreValue
@onready var round_value = $TopBar/MarginContainer2/RoundContainer/RoundValue
@onready var level_value = $TopBar/MarginContainer3/LevelContainer/LevelValue
@onready var goal_value = $MarginContainer/GoalContainer/GoalValue
@onready var money_value = $MarginContainer2/MoneyContainer/MoneyValue
@onready var total_score_value = $MarginContainer3/TotalScore/TotalScoreValue
@onready var end_round_button = $EndRoundButton

# Initialize UI
func _ready():
	update_score(0)
	update_round(1, 5)
	update_level(1)
	update_goal(100)
	update_money(0)
	if end_round_button:
		end_round_button.pressed.connect(_on_end_round_pressed)
		end_round_button.visible = false

func show_end_round_button():
	if end_round_button:
		end_round_button.visible = true
		end_round_button.text = "End Round"

func hide_end_round_button():
	if end_round_button:
		end_round_button.visible = false

func _on_end_round_pressed():
	# Emit signal to GameManager to end the round
	get_parent().end_round_manually()

# Update functions
func update_score(round_score):
	score_value.text = str(round_score)

func update_total_score(total_score, target_score):
	total_score_value.text = str(total_score) + " / " + str(target_score)

func update_round(current, total):
	round_value.text = str(current) + "/" + str(total)

func update_level(value):
	level_value.text = str(value)

func update_goal(value):
	goal_value.text = str(value)

func update_money(value):
	money_value.text = str(value)

# Show a floating score effect
func show_score_popup(value, position, is_multiplier = false):
	var popup = ScorePopup.new()
	add_child(popup)
	popup.position = position
	popup.show_value(value, is_multiplier)
