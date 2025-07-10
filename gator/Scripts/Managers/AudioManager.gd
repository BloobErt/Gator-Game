# AudioManager.gd
# Centralized audio management system
extends Node

var audio_config: AudioConfig

# Audio players for different categories
@onready var sfx_players: Array[AudioStreamPlayer] = []
@onready var ui_player: AudioStreamPlayer
@onready var music_player: AudioStreamPlayer
@onready var voice_player: AudioStreamPlayer

var current_sfx_index: int = 0
var max_sfx_players: int = 10

func setup(config: AudioConfig):
	audio_config = config
	create_audio_players()
	apply_volume_settings()
	print("✅ AudioManager initialized")

func create_audio_players():
	# Create multiple SFX players for overlapping sounds
	for i in range(max_sfx_players):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer" + str(i)
		add_child(player)
		sfx_players.append(player)
	
	# Create dedicated players for other categories
	ui_player = AudioStreamPlayer.new()
	ui_player.name = "UIPlayer"
	add_child(ui_player)
	
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	add_child(music_player)
	
	voice_player = AudioStreamPlayer.new()
	voice_player.name = "VoicePlayer"
	add_child(voice_player)

func apply_volume_settings():
	if not audio_config:
		return
	
	# Set volume for each category
	for player in sfx_players:
		player.volume_db = linear_to_db(audio_config.master_volume * audio_config.sfx_volume)
	
	ui_player.volume_db = linear_to_db(audio_config.master_volume * audio_config.ui_volume)
	music_player.volume_db = linear_to_db(audio_config.master_volume * audio_config.music_volume)
	voice_player.volume_db = linear_to_db(audio_config.master_volume * audio_config.voice_volume)

# SFX Functions
func play_tooth_click():
	if audio_config and audio_config.tooth_click_sounds.size() > 0:
		var sound = audio_config.tooth_click_sounds[randi() % audio_config.tooth_click_sounds.size()]
		play_sfx(sound)

func play_bite_sound():
	if audio_config and audio_config.bite_sound:
		play_sfx(audio_config.bite_sound, 1.2)  # Slightly louder

func play_score_popup():
	if audio_config and audio_config.score_popup_sound:
		play_sfx(audio_config.score_popup_sound)

func play_multiplier_sound():
	if audio_config and audio_config.multiplier_sound:
		play_sfx(audio_config.multiplier_sound)

func play_artifact_use():
	if audio_config and audio_config.artifact_use_sound:
		play_sfx(audio_config.artifact_use_sound)

func play_tattoo_apply():
	if audio_config and audio_config.tattoo_apply_sound:
		play_sfx(audio_config.tattoo_apply_sound)

func play_shop_open():
	if audio_config and audio_config.shop_open_sound:
		play_sfx(audio_config.shop_open_sound)

func play_shop_close():
	if audio_config and audio_config.shop_close_sound:
		play_sfx(audio_config.shop_close_sound)

func play_drawer_slide():
	if audio_config and audio_config.drawer_slide_sound:
		play_sfx(audio_config.drawer_slide_sound)

# UI Sound Functions
func play_button_hover():
	if audio_config and audio_config.button_hover_sound:
		play_ui_sound(audio_config.button_hover_sound)

func play_button_click():
	if audio_config and audio_config.button_click_sound:
		play_ui_sound(audio_config.button_click_sound)

func play_error():
	if audio_config and audio_config.error_sound:
		play_ui_sound(audio_config.error_sound)

func play_success():
	if audio_config and audio_config.success_sound:
		play_ui_sound(audio_config.success_sound)

func play_coin():
	if audio_config and audio_config.coin_sound:
		play_ui_sound(audio_config.coin_sound)

# Music Functions
func play_music(music_type: String):
	var stream: AudioStream = null
	
	match music_type:
		"main_menu":
			stream = audio_config.main_menu_music if audio_config else null
		"gameplay":
			stream = audio_config.gameplay_music if audio_config else null
		"shop":
			stream = audio_config.shop_music if audio_config else null
		"victory":
			stream = audio_config.victory_music if audio_config else null
		"defeat":
			stream = audio_config.defeat_music if audio_config else null
	
	if stream:
		crossfade_music(stream)

func crossfade_music(new_stream: AudioStream):
	if not music_player:
		return
	
	var fade_time = audio_config.music_crossfade_time if audio_config else 1.0
	
	if music_player.playing:
		# Fade out current music
		var tween = create_tween()
		tween.set_parallel(true)
		
		var current_volume = music_player.volume_db
		tween.tween_property(music_player, "volume_db", -80, fade_time)
		
		# Wait for fade out, then change music
		tween.tween_callback(func():
			music_player.stream = new_stream
			music_player.play()
			music_player.volume_db = -80
			
			# Fade in new music
			var fade_in_tween = create_tween()
			fade_in_tween.tween_property(music_player, "volume_db", current_volume, fade_time)
		).set_delay(fade_time)
	else:
		# No current music, just start new one
		music_player.stream = new_stream
		music_player.play()

func stop_music():
	if music_player:
		music_player.stop()

# Core Audio Functions
func play_sfx(stream: AudioStream, volume_multiplier: float = 1.0):
	if not stream or sfx_players.size() == 0:
		return
	
	# Find an available SFX player
	var player = get_next_sfx_player()
	
	# Apply randomized pitch if enabled
	if audio_config and audio_config.randomize_pitch:
		var pitch_variation = audio_config.pitch_variation
		player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	else:
		player.pitch_scale = 1.0
	
	# Set volume
	var base_volume = linear_to_db(audio_config.master_volume * audio_config.sfx_volume * volume_multiplier) if audio_config else 0.0
	player.volume_db = base_volume
	
	player.stream = stream
	player.play()

func play_ui_sound(stream: AudioStream):
	if not stream or not ui_player:
		return
	
	ui_player.stream = stream
	ui_player.play()

func get_next_sfx_player() -> AudioStreamPlayer:
	# Round-robin through SFX players to allow overlapping sounds
	var player = sfx_players[current_sfx_index]
	current_sfx_index = (current_sfx_index + 1) % sfx_players.size()
	return player

# Volume Control
func set_master_volume(volume: float):
	if audio_config:
		audio_config.master_volume = clamp(volume, 0.0, 1.0)
		apply_volume_settings()

func set_sfx_volume(volume: float):
	if audio_config:
		audio_config.sfx_volume = clamp(volume, 0.0, 1.0)
		apply_volume_settings()

func set_music_volume(volume: float):
	if audio_config:
		audio_config.music_volume = clamp(volume, 0.0, 1.0)
		apply_volume_settings()

func set_ui_volume(volume: float):
	if audio_config:
		audio_config.ui_volume = clamp(volume, 0.0, 1.0)
		apply_volume_settings()

# Utility Functions
func stop_all_sfx():
	for player in sfx_players:
		player.stop()

func stop_all_audio():
	stop_all_sfx()
	if ui_player:
		ui_player.stop()
	if music_player:
		music_player.stop()
	if voice_player:
		voice_player.stop()

func is_music_playing() -> bool:
	return music_player and music_player.playing

func get_music_position() -> float:
	return music_player.get_playback_position() if music_player else 0.0

# Debug Functions
func debug_play_random_sound():
	if audio_config and audio_config.tooth_click_sounds.size() > 0:
		play_tooth_click()

func debug_test_all_sounds():
	print("🔊 Testing all sounds...")
	play_tooth_click()
	await get_tree().create_timer(0.5).timeout
	play_bite_sound()
	await get_tree().create_timer(0.5).timeout
	play_button_click()
	await get_tree().create_timer(0.5).timeout
	play_success()
