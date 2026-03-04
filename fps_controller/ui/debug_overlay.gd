# debug_overlay.gd
extends Node

@onready var _label_fps: Label = %LabelFPS
@onready var _label_state: Label = %LabelState
@onready var _label_speed: Label = %LabelSpeed
@onready var _label_on_floor: Label = %LabelOnFloor
@onready var _label_light_level: Label = %LabelLightLevel
@onready var _label_shadow: Label = %LabelShadow
@onready var _label_interactable: Label = %LabelInteractable

@onready var _light_detector: Node = %LightDetector
@onready var _movement: Node = %MovementComponent
@onready var _body: CharacterBody3D = get_parent()
@onready var _interaction: Node = %InteractionComponent


func _process(_delta: float) -> void:
	_label_fps.text = "FPS: %d" % Engine.get_frames_per_second()
	_label_state.text = "State: %s" % _movement.State.keys()[_movement.state]
	_label_speed.text = "Speed: %.2f" % Vector3(_body.velocity.x, 0.0, _body.velocity.z).length()
	_label_on_floor.text = "On Floor: %s" % ("YES" if _body.is_on_floor() else "NO")
	_label_light_level.text = "Light: %.2f" % _light_detector.light_level
	_label_shadow.text = "Shadow: %s" % ("YES" if _light_detector.in_shadow else "NO")
	_label_shadow.modulate = Color.RED if _light_detector.in_shadow else Color.GREEN
	_label_interactable.text = "Interactable: %s" % (_interaction._focused.name if _interaction._focused else "None")
