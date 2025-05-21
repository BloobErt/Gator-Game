class_name ScorePopup
extends Node2D

var value = 0
var is_multiplier = false

func _ready():
	# Set up the animation
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	
	# Move up and fade out
	tween.tween_property(self, "position:y", position.y - 100, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0, 1.0)
	
	# Remove after animation
	tween.tween_callback(queue_free)

func _draw():
	# Draw the score text
	var font_color = Color(1, 0.8, 0.2) # Gold
	if is_multiplier:
		font_color = Color(1, 0.4, 0.4) # Red
	
	var text = "+" + str(value)
	if is_multiplier:
		text += " x2!"
	
	# Draw shadow first
	draw_string(ThemeDB.fallback_font, Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(0, 0, 0, 0.5))
	# Draw main text
	draw_string(ThemeDB.fallback_font, Vector2(0, 0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, font_color)

func show_value(new_value, new_is_multiplier = false):
	value = new_value
	is_multiplier = new_is_multiplier
	queue_redraw()
