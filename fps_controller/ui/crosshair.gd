# crosshair.gd
# Draws an animated dot crosshair. Color changes on entity focus.
# Node setup: set Anchors Preset to "Center" in the Inspector — no anchor code needed here.
extends Control

const RADIUS: float = 2.0
const RADIUS_FOCUSED: float = 3.5
const LERP_SPEED: float = 20.0
const COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)

var _interaction: Node
var _current_radius: float = RADIUS


func setup(interaction_component: Node) -> void:
	_interaction = interaction_component
	_interaction.interactable_focused.connect(_on_interactable_focused)
	_interaction.interactable_unfocused.connect(_on_unfocused)
	_interaction.entity_focused.connect(_on_entity_focused)
	_interaction.entity_unfocused.connect(_on_unfocused)


func _process(delta: float) -> void:
	var target_radius := RADIUS_FOCUSED if _interaction._focused else RADIUS
	_current_radius = lerp(_current_radius, target_radius, delta * LERP_SPEED)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, _current_radius, COLOR)


func _on_interactable_focused(_interactable: Node) -> void:
	modulate = Color.WHITE


func _on_entity_focused(entity: Node) -> void:
	if entity.is_in_group("NPC"):
		modulate = Color.GREEN
	elif entity.is_in_group("Enemy"):
		modulate = Color.RED


func _on_unfocused() -> void:
	modulate = Color.WHITE
