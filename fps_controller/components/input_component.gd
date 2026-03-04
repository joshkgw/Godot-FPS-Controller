# input_component.gd
# Translates raw input into a clean API consumed by other components.
# Continuous actions are polled each frame; discrete actions emit signals AND set flags.
extends Node

signal jump_requested
signal crouch_toggled
signal interact_requested

## Directional and modifier inputs — read each frame by MovementComponent.
var input_dir: Vector2 = Vector2.ZERO
var wants_sprint: bool = false
var wants_walk: bool = false
var wants_lean_left: bool = false
var wants_lean_right: bool = false

## True while jump is held; used by MovementComponent for variable-height jumps.
var wants_jump_held: bool = false

## Consumed (set back to false) by MovementComponent after processing.
var wants_jump: bool = false
var wants_crouch: bool = false


func _process(_delta: float) -> void:
	input_dir = Input.get_vector("left", "right", "forward", "backward")
	wants_sprint = Input.is_action_pressed("sprint")
	wants_walk = Input.is_action_pressed("walk")
	wants_jump_held = Input.is_action_pressed("jump")
	wants_lean_left = Input.is_action_pressed("lean_left")
	wants_lean_right = Input.is_action_pressed("lean_right")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		wants_jump = true
		jump_requested.emit()
	elif event.is_action_pressed("crouch"):
		wants_crouch = true
		crouch_toggled.emit()
	elif event.is_action_pressed("interact"):
		interact_requested.emit()
