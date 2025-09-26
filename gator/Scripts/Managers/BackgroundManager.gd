# BackgroundManager.gd
# Dedicated manager for all background animations and transitions
extends Node

signal background_synced
signal shop_synced
signal transition_completed(transition_name: String)

var ui_config: UIConfig

# Animation references
var bg_3d_anim: AnimationPlayer
var bg_2d_anim: AnimationPlayer
var bg_2d_anim_tree: AnimationTree
var bg_2d_texture: TextureRect

# State tracking
var current_mode: String = "game"
var is_transitioning: bool = false

func setup(config: UIConfig):
	ui_config = config
	find_animation_nodes()
	setup_signal_connections()
	print("✅ BackgroundManager initialized")

func find_animation_nodes():
	# Find all the background animation components
	bg_3d_anim = get_node("../Camera3D/dBackground/AnimationPlayer")
	bg_2d_anim = get_node("../Camera3D/Background/AnimationPlayer") 
	bg_2d_anim_tree = get_node("../Camera3D/Background/AnimationTree")
	bg_2d_texture = get_node("../Camera3D/Background/TextureRect")
	
	if bg_3d_anim:
		print("✅ Found 3D background AnimationPlayer")
	if bg_2d_anim_tree:
		print("✅ Found 2D background AnimationTree")

func setup_signal_connections():
	# Connect to AnimationTree completion
	if bg_2d_anim_tree and bg_2d_anim_tree.has_signal("animation_finished"):
		bg_2d_anim_tree.animation_finished.connect(_on_animation_finished)

# === PUBLIC INTERFACE ===

func start_game_mode():
	"""Start the main gameplay background animations"""
	current_mode = "game"
	
	# Start 3D background loop
	if bg_3d_anim:
		bg_3d_anim.play("game_loop_3d")
	
	# Start 2D background in game mode
	if bg_2d_anim_tree:
		bg_2d_anim_tree.active = true
		var playback = bg_2d_anim_tree.get("parameters/playback")
		playback.travel("game_loop")
	
	# Hide 2D overlay to show 3D scene
	set_2d_overlay_visibility(0.0)
	
	print("🎮 Started game mode background")

func transition_to_shop():
	"""Start transition from game to shop"""
	if is_transitioning:
		return
	
	current_mode = "transitioning_to_shop"
	is_transitioning = true
	
	# Pause 3D background
	if bg_3d_anim:
		bg_3d_anim.pause()
	
	# Start transition animation
	if bg_2d_anim_tree:
		var playback = bg_2d_anim_tree.get("parameters/playback")
		playback.travel("transition_to_shop")
	
	# Show 2D overlay for transition
	set_2d_overlay_visibility(1.0)
	
	print("🎬 Started transition to shop")

func start_shop_mode():
	"""Start shop background animations"""
	current_mode = "shop"
	is_transitioning = false
	
	# Keep 3D paused
	# Start shop loop animation
	if bg_2d_anim_tree:
		var playback = bg_2d_anim_tree.get("parameters/playback")
		playback.travel("shop_loop")
	
	print("🛒 Started shop mode background")

func transition_to_game():
	"""Start transition from shop back to game"""
	if is_transitioning:
		return
	
	current_mode = "transitioning_to_game"
	is_transitioning = true
	
	# Start transition animation
	if bg_2d_anim_tree:
		var playback = bg_2d_anim_tree.get("parameters/playback")
		playback.travel("transition_to_game")
	
	print("🎬 Started transition to game")

func set_2d_overlay_visibility(alpha: float, animate: bool = false):
	"""Control the 2D background overlay visibility"""
	if not bg_2d_texture:
		return
	
	if animate:
		var fade_time = ui_config.transition_fade_time if ui_config else 0.2
		var tween = create_tween()
		tween.tween_property(bg_2d_texture, "modulate:a", alpha, fade_time)
	else:
		bg_2d_texture.modulate.a = alpha

# === SIGNAL HANDLERS (called by animations) ===

func emit_3d_frame_sync():
	"""Called by 3D background animation every frame"""
	emit_signal("background_synced")

func emit_shop_loop_sync():
	"""Called by shop background animation every frame"""
	emit_signal("shop_synced")

func _on_animation_finished(anim_name: StringName):
	"""Handle AnimationTree state transitions"""
	print("🎬 Animation finished: ", anim_name)
	
	match anim_name:
		"transition_to_shop":
			start_shop_mode()
			emit_signal("transition_completed", "to_shop")
			
		"transition_to_game":
			# Hide 2D overlay with smooth fade
			set_2d_overlay_visibility(0.0, true)
			
			# Resume 3D background
			if bg_3d_anim:
				bg_3d_anim.play("game_loop_3d")
			
			# Set 2D to game loop
			if bg_2d_anim_tree:
				var playback = bg_2d_anim_tree.get("parameters/playback")
				playback.travel("game_loop")
			
			current_mode = "game"
			is_transitioning = false
			emit_signal("transition_completed", "to_game")

# === UTILITY FUNCTIONS ===

func get_current_mode() -> String:
	return current_mode

func is_in_transition() -> bool:
	return is_transitioning

func force_game_mode():
	"""Emergency function to force back to game mode"""
	is_transitioning = false
	start_game_mode()

func pause_all_animations():
	"""Pause all background animations"""
	if bg_3d_anim:
		bg_3d_anim.pause()
	if bg_2d_anim_tree:
		bg_2d_anim_tree.active = false

func resume_animations():
	"""Resume appropriate animations based on current mode"""
	if bg_2d_anim_tree:
		bg_2d_anim_tree.active = true
	
	match current_mode:
		"game":
			start_game_mode()
		"shop":
			start_shop_mode()

# === DEBUG FUNCTIONS ===

func debug_print_state():
	if ui_config and ui_config.debug_mode:
		print("=== BACKGROUND DEBUG ===")
		print("Current mode: ", current_mode)
		print("Is transitioning: ", is_transitioning)
		print("3D anim playing: ", bg_3d_anim.is_playing() if bg_3d_anim else "N/A")
		print("2D overlay alpha: ", bg_2d_texture.modulate.a if bg_2d_texture else "N/A")
