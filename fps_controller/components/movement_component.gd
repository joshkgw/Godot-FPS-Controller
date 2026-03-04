# movement_component.gd
# Owns all movement: gravity, jumping, horizontal motion, crouching, stair stepping.
# Reusable on any CharacterBody3D — assign a controller node that exposes the input API
# defined in input_component.gd.
extends Node

signal state_changed(new_state: State)

enum State { IDLE, IDLE_CROUCH, CROUCHING, WALKING, JOGGING, SPRINTING, AIR }

## Assign in the owning entity's _ready (e.g. Player.gd sets movement.controller = input).
var controller: Node = null

@onready var body: CharacterBody3D = get_parent()
@onready var camera_controller: Node = %CameraController
@onready var standup_check: ShapeCast3D = %StandupCheck
@onready var crouching_collision: CollisionShape3D = %CrouchingCollisionShape
@onready var standing_collision: CollisionShape3D = %StandingCollisionShape

@export_group("Movement Speeds")
@export var speed_sprint: float = 3.5
@export var speed_jog: float = 2.5
@export var speed_walk: float = 1.6
@export var speed_crouch: float = 1.0

@export_group("Jump & Gravity")
@export var jump_velocity: float = 10.0
@export var gravity_fall: float = 3.0   ## Snappy landing.
@export var gravity_rise: float = 4.0   ## Fast ascent.
@export var gravity_cut: float = 8.0    ## Short hop when jump released early.

@export_group("Stair Stepping")
@export var max_step_height: float = 0.75
@export var step_probe_dist: float = 0.35

const LERP_SPEED: float = 10.0

var state: State = State.IDLE
var is_crouching: bool = false
var is_moving: bool = false
var lean_amount: float = 0.0
var current_speed: float = 0.0
var movement_dir: Vector3 = Vector3.ZERO

var _jumped: bool = false
var _last_velocity_y: float = 0.0


func _ready() -> void:
	body.floor_snap_length = 0.1


## Called by Player._physics_process before move_and_slide().
func update(delta: float) -> void:
	_update_state()
	_apply_gravity(delta)
	_apply_movement(delta)
	_update_lean(delta)
	_check_landing()


# --- State ---

func _update_state() -> void:
	is_moving = controller.input_dir != Vector2.ZERO

	if controller.wants_crouch:
		if not (is_crouching and standup_check.is_colliding()):
			is_crouching = !is_crouching
		controller.wants_crouch = false

	var new_state: State
	if not body.is_on_floor():
		new_state = State.AIR
	elif is_crouching:
		new_state = State.CROUCHING if is_moving else State.IDLE_CROUCH
	elif is_moving:
		if controller.wants_sprint:   new_state = State.SPRINTING
		elif controller.wants_walk:   new_state = State.WALKING
		else:                         new_state = State.JOGGING
	else:
		new_state = State.IDLE

	if new_state == state:
		return

	state = new_state
	state_changed.emit(state)

	var crouched := state in [State.CROUCHING, State.IDLE_CROUCH]
	standing_collision.disabled = crouched
	crouching_collision.disabled = not crouched
	current_speed = _speed_for_state(state)


func _speed_for_state(s: State) -> float:
	match s:
		State.SPRINTING:                    return speed_sprint
		State.JOGGING:                      return speed_jog
		State.WALKING:                      return speed_walk
		State.CROUCHING, State.IDLE_CROUCH: return speed_crouch
		_:                                  return current_speed  # AIR / IDLE: preserve momentum


# --- Gravity & Jumping ---

func _apply_gravity(delta: float) -> void:
	if body.is_on_floor():
		if controller.wants_jump:
			controller.wants_jump = false
			if not (is_crouching and standup_check.is_colliding()) and abs(lean_amount) < 0.3:
				body.velocity.y = jump_velocity
				_jumped = true
		else:
			_jumped = false
		return

	controller.wants_jump = false  # Prevent jump queuing while airborne.

	if body.velocity.y > 0 and not controller.wants_jump_held:
		body.velocity += body.get_gravity() * gravity_cut * delta
	elif body.velocity.y > 0:
		body.velocity += body.get_gravity() * gravity_rise * delta
	else:
		body.velocity += body.get_gravity() * gravity_fall * delta


# --- Horizontal Movement ---

func _apply_movement(delta: float) -> void:
	movement_dir = lerp(
		movement_dir,
		(body.transform.basis * Vector3(controller.input_dir.x, 0.0, controller.input_dir.y)).normalized(),
		delta * LERP_SPEED
	)

	if movement_dir:
		body.velocity.x = movement_dir.x * current_speed
		body.velocity.z = movement_dir.z * current_speed
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, current_speed)
		body.velocity.z = move_toward(body.velocity.z, 0.0, current_speed)


# --- Stair Stepping ---

## Called by Player._physics_process after move_and_slide().
func step_up_check() -> void:
	if not body.is_on_floor() or body.velocity.y > 0:
		return

	var step_dir := Vector3(movement_dir.x, 0.0, movement_dir.z).normalized()
	if step_dir.is_zero_approx() or not _has_wall_collision(step_dir):
		return

	var result := PhysicsTestMotionResult3D.new()
	var params := PhysicsTestMotionParameters3D.new()

	for i in range(1, 21):
		var test_height: float = i * (max_step_height / 20.0)

		if body.test_move(body.global_transform, Vector3.UP * test_height):
			return

		var elevated_xform := body.global_transform.translated(Vector3.UP * test_height)
		if body.test_move(elevated_xform, step_dir * step_probe_dist):
			continue

		params.from = elevated_xform.translated(step_dir * step_probe_dist)
		params.motion = Vector3.DOWN * (test_height + 0.1)
		if not PhysicsServer3D.body_test_motion(body.get_rid(), params, result):
			return

		var actual_step: float = test_height - result.get_travel().length()
		if actual_step <= 0.01:
			return

		camera_controller.apply_step_smoothing()
		body.global_position.y += actual_step
		body.velocity.y = 0.0
		_nudge_onto_step(step_dir, actual_step)
		body.apply_floor_snap()
		return


func _has_wall_collision(step_dir: Vector3) -> bool:
	for i in body.get_slide_collision_count():
		var col := body.get_slide_collision(i)
		if abs(col.get_normal().y) < 0.7 and step_dir.dot(col.get_normal()) < 0.0:
			return true
	return false


func _nudge_onto_step(step_dir: Vector3, actual_step: float) -> void:
	var params := PhysicsTestMotionParameters3D.new()
	var result := PhysicsTestMotionResult3D.new()
	params.motion = Vector3.DOWN * (actual_step + 0.1)
	for j in range(1, 8):
		var nudge: float = j * (step_probe_dist / 7.0)
		params.from = body.global_transform.translated(step_dir * nudge)
		if PhysicsServer3D.body_test_motion(body.get_rid(), params, result):
			body.global_position += step_dir * nudge
			return


# --- Lean ---

func _update_lean(delta: float) -> void:
	if not body.is_on_floor():
		lean_amount = lerp(lean_amount, 0.0, delta * LERP_SPEED)
		return

	var target_lean: float = 0.0
	if controller.wants_lean_right:
		target_lean = 1.0
	elif controller.wants_lean_left:
		target_lean = -1.0
	lean_amount = lerp(lean_amount, target_lean, delta * LERP_SPEED)


# --- Landing ---

func _check_landing() -> void:
	if body.is_on_floor() and _last_velocity_y < -3.0:
		camera_controller.apply_landing_bob(_last_velocity_y)
	_last_velocity_y = body.velocity.y
