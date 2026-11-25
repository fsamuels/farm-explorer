extends "res://scripts/vehicle.gd"
## The Cub Cadet 550 UTV (D-127, D-138, D-180): vehicle.gd with a dump bed. The
## body is the downloaded Polaris Ranger EV (models/ranger_ev.glb, built by
## tools/build_ranger_ev_model.py), whose cargo box is a "Bed" node hinged at its
## rear edge, so `bed` is just that node.

func _ready() -> void:
	bed = $Model.get_node_or_null("Bed") as Node3D
	super._ready()
