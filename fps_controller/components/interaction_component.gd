# interaction_component.gd
# Detects interactable objects and named entities in front of the player via cone raycasting.
extends Node

signal interactable_focused(interactable: Node)
signal interactable_unfocused
signal entity_focused(entity: Node)
signal entity_unfocused

@onready var _body: CharacterBody3D = get_parent()
@onready var _camera: Camera3D = %Camera3D

@export_group("Reach")
@export var interact_reach: float = 1.5
@export var entity_reach: float = 5.0

@export_group("Ray Spread")
@export var ray_spread: float = 0.025
@export var ray_count: int = 4

var _focused: Node = null
var _focused_entity: Node = null


func _physics_process(_delta: float) -> void:
	_update_focus(_cast_cone(interact_reach, ["Openable"]), ["Openable"])
	_update_entity_focus(_cast_cone(entity_reach, ["NPC", "Enemy"]), ["NPC", "Enemy"])


func try_interact(action: StringName) -> void:
	if _focused and _focused.has_method("interact"):
		_focused.interact(action, _body)


func _update_focus(hit: Dictionary, groups: Array) -> void:
	var interactable := _node_in_groups(hit, groups)
	if interactable == _focused:
		return
	_focused = interactable
	if _focused:
		interactable_focused.emit(_focused)
	else:
		interactable_unfocused.emit()


func _update_entity_focus(hit: Dictionary, groups: Array) -> void:
	var entity := _node_in_groups(hit, groups)
	if entity == _focused_entity:
		return
	_focused_entity = entity
	if _focused_entity:
		entity_focused.emit(_focused_entity)
	else:
		entity_unfocused.emit()


## Casts a cone of rays from the camera; returns the first hit whose collider is in [groups].
func _cast_cone(reach: float, groups: Array) -> Dictionary:
	var space := _body.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	ray.exclude = [_body]
	var forward := -_camera.global_transform.basis.z

	var origins: Array[Vector3] = [_camera.global_position]
	for i in ray_count:
		var angle: float = (TAU / ray_count) * i
		origins.append(_camera.global_position + _camera.global_transform.basis * Vector3(
			cos(angle) * ray_spread, sin(angle) * ray_spread, 0.0
		))

	for origin in origins:
		ray.from = origin
		ray.to = origin + forward * reach
		var hit: Dictionary = space.intersect_ray(ray)
		if not hit.is_empty() and _node_in_groups(hit, groups) != null:
			return hit

	return {}


## Returns the collider or its parent if it belongs to any of [groups]; otherwise null.
func _node_in_groups(hit: Dictionary, groups: Array) -> Node:
	if hit.is_empty():
		return null
	for node: Node in [hit.collider, hit.collider.get_parent()]:
		for group in groups:
			if node.is_in_group(group):
				return node
	return null
