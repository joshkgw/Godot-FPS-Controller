# player.gd
# Scene root. Orchestrates physics update order and wires components via signals.
# Contains no gameplay logic of its own.
extends CharacterBody3D

@onready var input: Node = %InputComponent
@onready var movement: Node = %MovementComponent
@onready var interaction: Node = %InteractionComponent
@onready var user_interface: Control = $UserInterface


func _ready() -> void:
	add_to_group("Player")
	movement.controller = input
	input.interact_requested.connect(interaction.try_interact.bind("interact"))
	user_interface.setup(interaction)


func _physics_process(delta: float) -> void:
	movement.update(delta)
	move_and_slide()
	movement.step_up_check()
