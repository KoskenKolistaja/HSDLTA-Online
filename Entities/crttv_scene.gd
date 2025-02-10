extends Node3D


@export var sub_viewport: SubViewport

@onready var material = $CRTTV2.get_surface_override_material(1)

@export var camera: Node3D


var current_time = 0

func _ready():
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE  # Updates only once per call
	
	if camera:
		spawn_camera()
	

func spawn_camera():
	var camera_instance = Camera3D.new()
	camera_instance.global_transform = camera.global_transform
	sub_viewport.add_child(camera_instance)



func _physics_process(delta):
	if camera:
		if current_time + 100 < Time.get_ticks_msec():
			sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE  # Updates only once per call
			var tex = sub_viewport.get_texture()
			# Set sprite texture.
			material.set_shader_parameter("tex_frg_2", tex)
			current_time = Time.get_ticks_msec()
	else:
		return
