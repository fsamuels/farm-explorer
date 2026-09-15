extends Control

@export var player_path: NodePath
@export var ground_origin := Vector2(49.4, -33.7)
@export var ground_half_extent := 260.0

@onready var player: Node3D = get_node(player_path)
@onready var marker: Polygon2D = $Map/Marker

func _process(_delta: float) -> void:
	if player == null:
		return

	var u := (player.global_position.x - ground_origin.x + ground_half_extent) / (ground_half_extent * 2.0)
	var v := (player.global_position.z - ground_origin.y + ground_half_extent) / (ground_half_extent * 2.0)
	var map_size: Vector2 = $Map.size
	marker.position = Vector2(clampf(u, 0.0, 1.0), clampf(v, 0.0, 1.0)) * map_size
	marker.rotation = -player.rotation.y
