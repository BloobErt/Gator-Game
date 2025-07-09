# AudioLibrary.gd
# Centralized audio resource management
class_name AudioLibrary
extends Resource

@export var tooth_sounds: Dictionary = {
	"click": [],  # Array of AudioStreams for variation
	"bite": null,
	"multiplier": null
}

@export var ui_sounds: Dictionary = {
	"button_hover": null,
	"button_click": null,
	"error": null,
	"success": null
}

@export var shop_sounds: Dictionary = {
	"open": null,
	"close": null,
	"purchase": null,
	"cant_afford": null,
	"drawer_open": null,
	"drawer_close": null
}

@export var artifact_sounds: Dictionary = {
	"activate": null,
	"depleted": null,
	"evolve": null
}

@export var ambient_sounds: Dictionary = {
	"swamp_background": null,
	"water_splash": null,
	"gator_growl": null
}
