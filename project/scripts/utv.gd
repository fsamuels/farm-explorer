extends "res://scripts/vehicle.gd"
## The Cub Cadet 550 UTV (D-127, D-138): vehicle.gd with a dump bed built by
## utv_builder.gd on top of the downloaded Ranger body. The bed is added before
## vehicle.gd's own _ready runs, so `bed` is set when it looks for it.

const UtvBuilder := preload("res://scripts/utv_builder.gd")

func _ready() -> void:
	bed = UtvBuilder.build($Model as Node3D)
	super._ready()
