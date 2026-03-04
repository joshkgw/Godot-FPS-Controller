# user_interface.gd
extends Control

@onready var crosshair = %Crosshair  # works here — same scene


func setup(interaction: Node) -> void:
	crosshair.setup(interaction)
