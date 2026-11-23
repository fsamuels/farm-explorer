extends "res://scripts/vehicle.gd"
## The Cub Cadet 550 UTV (D-127): vehicle.gd with a body built from primitives
## (utv_builder.gd) and a dump bed. The body is built before vehicle.gd's own
## _ready runs, so it can split the wheel meshes into spinning wheels.

const UtvBuilder := preload("res://scripts/utv_builder.gd")

func _ready() -> void:
	bed = UtvBuilder.build($Model as Node3D)
	super._ready()
