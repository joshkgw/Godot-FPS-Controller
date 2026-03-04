# light_detector.gd
# Samples average light level at the player position using a SubViewport probe.
# Scene setup: add a Timer child (wait_time: 0.1, autostart: true),
# connect its timeout signal to _sample_light in the editor.
extends Node

signal entered_shadow
signal entered_light

@onready var _sub_viewport: SubViewport = %SubViewport
@onready var _probe_camera: Camera3D = %ProbeCamera
@onready var _light_mesh: MeshInstance3D = %OctahedronMesh
@onready var _player: CharacterBody3D = get_parent()

var light_level: float = 0.0
var in_shadow: bool = false

var _last_player_pos: Vector3 = Vector3.ZERO


func _sample_light() -> void:
	if _player.global_position.distance_squared_to(_last_player_pos) > 0.0001:
		_last_player_pos = _player.global_position
		_light_mesh.global_position = _player.global_position
		_probe_camera.global_position = _player.global_position + Vector3(0.0, 0.8, 0.0)

	var image: Image = _sub_viewport.get_texture().get_image()
	image.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	var new_level: float = image.get_pixel(0, 0).get_luminance()

	if abs(new_level - light_level) > 0.05:
		light_level = new_level
		var now_in_shadow := light_level <= 0.6
		if now_in_shadow != in_shadow:
			in_shadow = now_in_shadow
			if in_shadow:
				entered_shadow.emit()
			else:
				entered_light.emit()

	light_level = new_level
