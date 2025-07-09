# AudioConfig.gd
# Configuration for all game audio
class_name AudioConfig
extends Resource

# Volume Settings
@export_group("Volume Controls")
@export var master_volume: float = 1.0
@export var sfx_volume: float = 0.8
@export var music_volume: float = 0.6
@export var ui_volume: float = 0.7
@export var voice_volume: float = 0.9

# Sound Effect Settings
@export_group("Sound Effects")
@export var tooth_click_sounds: Array[AudioStream] = []
@export var bite_sound: AudioStream
@export var score_popup_sound: AudioStream
@export var multiplier_sound: AudioStream
@export var artifact_use_sound: AudioStream
@export var tattoo_apply_sound: AudioStream
@export var shop_open_sound: AudioStream
@export var shop_close_sound: AudioStream
@export var drawer_slide_sound: AudioStream

# UI Sounds
@export_group("UI Audio")
@export var button_hover_sound: AudioStream
@export var button_click_sound: AudioStream
@export var tooltip_show_sound: AudioStream
@export var error_sound: AudioStream
@export var success_sound: AudioStream
@export var coin_sound: AudioStream

# Music Settings
@export_group("Music")
@export var main_menu_music: AudioStream
@export var gameplay_music: AudioStream
@export var shop_music: AudioStream
@export var victory_music: AudioStream
@export var defeat_music: AudioStream
@export var music_crossfade_time: float = 2.0

# Advanced Audio
@export_group("Audio Behavior")
@export var randomize_pitch: bool = true
@export var pitch_variation: float = 0.1
@export var max_simultaneous_sounds: int = 10
@export var enable_audio_ducking: bool = true  # lower music when SFX plays
@export var ducking_amount: float = 0.3
