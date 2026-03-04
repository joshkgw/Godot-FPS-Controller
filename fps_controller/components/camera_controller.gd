# camera_controller.gd
# Handles mouse look, FOV, headbob, sway, lean visuals, and step/landing smoothing.
# Runs in its own _process (visual only — reads physics state set by MovementComponent).
extends Node

@onready var _head: Node3D = %Head
@onready var _lean_pivot: Node3D = %LeanPivot
@onready var _eyes: Node3D = %Eyes
@onready var _camera: Camera3D = %Camera3D
@onready var _body: CharacterBody3D = get_parent()
@onready var _movement: Node = %MovementComponent

@export_group("Mouse Look")
@export var mouse_sensitivity: float = 0.2

@export_group("Field of View")
@export var base_fov: float = 90.0
@export var sprint_fov_multiplier: float = 1.1

@export_group("Head Height")
@export var standing_head_y: float = 1.6
@export var crouching_head_y: float = 0.8

@export_group("Headbob")
@export var headbob_sprint_speed: float = 18
@export var headbob_sprint_intensity: float = 0.3
@export var headbob_jog_speed: float = 13.0
@export var headbob_jog_intensity: float = 0.2
@export var headbob_walk_speed: float = 10.0
@export var headbob_walk_intensity: float = 0.2
@export var headbob_crouch_speed: float = 7.5
@export var headbob_crouch_intensity: float = 0.1

@export_group("Lean")
@export var lean_angle: float = 8.0
@export var lean_offset: float = 0.6

@export_group("Feel")
@export var lerp_speed: float = 10.0
@export var sway_intensity: float = 0.0125

var _headbob_index: float = 0.0
var _sway_vector: Vector2 = Vector2.ZERO
var _saved_camera_world_y: float = -INF
var _landing_offset: float = 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _process(delta: float) -> void:
	_update_head_height(delta)
	_update_fov(delta)
	_update_headbob(delta)
	_update_sway(delta)
	_update_lean(delta)


## Called by MovementComponent.step_up_check() after a step is taken.
func apply_step_smoothing() -> void:
	_saved_camera_world_y = _head.global_position.y


## Called by MovementComponent._check_landing() on hard landings.
func apply_landing_bob(velocity_y: float) -> void:
	_landing_offset = clampf(velocity_y * 0.08, -1.0, 0.0)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	_body.rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
	_head.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
	_head.rotation.x = clamp(_head.rotation.x, deg_to_rad(-90), deg_to_rad(90))


func _update_head_height(delta: float) -> void:
	var target_y: float = crouching_head_y if _movement.is_crouching else standing_head_y
	_landing_offset = lerp(_landing_offset, 0.0, delta * lerp_speed)

	if _saved_camera_world_y != -INF:
		_head.global_position.y = _saved_camera_world_y
		_head.position.y = clampf(
			_head.position.y,
			target_y - _movement.max_step_height,
			target_y + _movement.max_step_height
		)
		var recover_speed := maxf(_body.velocity.length() * delta, _movement.speed_jog * delta)
		_head.position.y = move_toward(_head.position.y, target_y, recover_speed)
		_saved_camera_world_y = _head.global_position.y
		if abs(_head.position.y - target_y) < 0.001:
			_head.position.y = target_y
			_saved_camera_world_y = -INF
	else:
		_head.position.y = lerp(_head.position.y, target_y + _landing_offset, delta * lerp_speed)


func _update_fov(delta: float) -> void:
	var target_fov := base_fov
	# Keep FOV elevated while sprint is held — prevents flickering when strafing while sprinting.
	if _movement.controller.wants_sprint and not _movement.is_crouching:
		target_fov = base_fov * sprint_fov_multiplier
	# Revert FOV when airborne from an intentional jump.
	if _movement.state == _movement.State.AIR and _movement._jumped:
		target_fov = base_fov
	_camera.fov = lerp(_camera.fov, target_fov, delta * lerp_speed)


func _update_headbob(delta: float) -> void:
	var bob_speed: float
	var bob_intensity: float

	match _movement.state:
		_movement.State.SPRINTING:
			bob_speed = headbob_sprint_speed
			bob_intensity = headbob_sprint_intensity
		_movement.State.WALKING:
			bob_speed = headbob_walk_speed
			bob_intensity = headbob_walk_intensity
		_movement.State.CROUCHING, _movement.State.IDLE_CROUCH:
			bob_speed = headbob_crouch_speed
			bob_intensity = headbob_crouch_intensity
		_:
			bob_speed = headbob_jog_speed
			bob_intensity = headbob_jog_intensity

	_headbob_index += bob_speed * delta

	var target_eye_y := sin(_headbob_index) * (bob_intensity / 3.0) if _movement.is_moving else 0.0
	var target_eye_x := sin(_headbob_index / 2.0) * (bob_intensity / 4.0) if _movement.is_moving else 0.0
	_eyes.position.y = lerp(_eyes.position.y, target_eye_y, delta * lerp_speed)
	_eyes.position.x = lerp(_eyes.position.x, target_eye_x, delta * lerp_speed)


func _update_sway(delta: float) -> void:
	_sway_vector = lerp(_sway_vector, _movement.controller.input_dir, delta * lerp_speed)
	_eyes.rotation.z = -_sway_vector.x * sway_intensity


func _update_lean(delta: float) -> void:
	var target_lean: float = _movement.lean_amount
	if target_lean != 0.0:
		target_lean *= _get_lean_scale()
	_lean_pivot.rotation.z = lerp(_lean_pivot.rotation.z, deg_to_rad(-target_lean * lean_angle), delta * lerp_speed * 2.0)
	_lean_pivot.position.x = lerp(_lean_pivot.position.x, target_lean * lean_offset, delta * lerp_speed * 2.0)


func _get_lean_scale() -> float:
	var space := _body.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	ray.exclude = [_body]

	var min_distance: float = lean_offset
	for i in 8:
		var angle: float = (TAU / 8.0) * i
		var dir: Vector3 = _body.global_transform.basis * Vector3(cos(angle), 0.0, sin(angle))
		ray.from = _camera.global_position
		ray.to = _camera.global_position + dir * 0.3
		var hit: Dictionary = space.intersect_ray(ray)
		if hit:
			min_distance = minf(min_distance, hit.position.distance_to(_camera.global_position))

	return min_distance / 0.3 if min_distance < 0.3 else 1.0
