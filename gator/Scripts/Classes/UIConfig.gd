# UIConfig.gd
# Configuration for UI behavior and animations
class_name UIConfig
extends Resource

# Animation Timings
@export_group("Animations")
@export var score_popup_duration: float = 1.0
@export var score_popup_rise_distance: float = 100.0
@export var tooltip_fade_in_time: float = 0.2
@export var tooltip_fade_out_time: float = 0.1
@export var button_hover_scale: float = 1.05
@export var drawer_slide_time: float = 0.6
@export var transition_fade_time: float = 0.5

# Feedback Settings
@export_group("User Feedback")
@export var enable_screen_shake: bool = true
@export var bite_screen_shake_intensity: float = 10.0
@export var bite_screen_shake_duration: float = 0.3
@export var show_damage_numbers: bool = true
@export var show_effect_descriptions: bool = true

# Tooltip Settings
@export_group("Tooltips")
@export var tooltip_follow_mouse: bool = true
@export var tooltip_offset: Vector2 = Vector2(15, -10)
@export var tooltip_max_width: float = 300
@export var tooltip_show_delay: float = 0.5
@export var tooltip_hide_delay: float = 0.1

# Visual Effects
@export_group("Effects")
@export var particle_intensity: float = 1.0  # multiplier for all particles
@export var enable_tooth_glow: bool = true
@export var multiplier_tooth_glow_color: Color = Color.GOLD
@export var safe_tooth_indicator_color: Color = Color.LIME_GREEN
@export var bite_tooth_warning_color: Color = Color.RED

# Layout Settings
@export_group("Layout")
@export var ui_scale: float = 1.0
@export var compact_mode: bool = false  # for smaller screens
@export var show_advanced_tooltips: bool = true
@export var auto_hide_ui_delay: float = 5.0  # seconds of inactivity

# Accessibility
@export_group("Accessibility")
@export var high_contrast_mode: bool = false
@export var large_text_mode: bool = false
@export var reduce_motion: bool = false
@export var colorblind_friendly: bool = false
