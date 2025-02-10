extends Node3D


@export var sub_viewport: SubViewport

@onready var material = $CRTTV2.get_surface_override_material(1)

#@onready var screen = $CRTTV2/surface_material_override/1/albedo_texture

var current_time = 0


func _physics_process(delta):
	
	if current_time + 200 < Time.get_ticks_msec():
		# Retrieve the captured Image using get_image().
		var img = sub_viewport.get_viewport().get_texture().get_image()
		# Convert Image to ImageTexture.
		var tex = sub_viewport.get_texture()
		# Set sprite texture.
		material.albedo_texture = tex
