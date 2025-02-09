extends CharacterBody3D
class_name Player

@export var nv_screen: ColorRect
@export var nv_light: SpotLight3D


const JUMP_VELOCITY := 4.5
const RAY_LENGTH := 1000.0  # Adjust the distance of the raycast

@onready var state_machine = $AnimationTree.get("parameters/playback")
@onready var camera := $HeadPivot/Camera3D

@export var sensitivity: float = 0.005
@export var vertical_limit: float = 80.0	# Maximum vertical rotation in degrees
@export var camera_rot_smoothing := 0.02 ## Bigger smooths more.

var movement_speed := 3.0
var rotation_x: float = 0.0	# Tracks vertical rotation
var look_input_smoother_tween: Tween = null

# Input vars, set by controller node
var move_input: Vector2 = Vector2.ZERO
var look_input: Vector2 = Vector2.ZERO
var jump_input := false
var sprint_input := false
var started_shooting_input := false
var shooting_input := false

var smoothed_look_input := Vector2.ZERO
var smoothed_look_goal := Vector2.ZERO


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # Locks the cursor


func _process(delta: float) -> void:
	if camera_rot_smoothing:
		if look_input_smoother_tween:
			look_input_smoother_tween.kill()
		look_input_smoother_tween = create_tween()
		look_input_smoother_tween.tween_property(self, "smoothed_look_input", look_input, camera_rot_smoothing)
		rotate_camera(smoothed_look_input)
	else:
		rotate_camera(look_input)
	# Reset look_input
	look_input = Vector2.ZERO


func rotate_camera(movement: Vector2):
	# Horizontal rotation (Y-axis)
	rotation_degrees.y -= movement.x * sensitivity * 100
	
	# Vertical rotation (X-axis)
	rotation_x -= movement.y * sensitivity * 100
	rotation_x = clamp(rotation_x, -vertical_limit, vertical_limit)
	$HeadPivot.rotation_degrees.x = rotation_x


func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if jump_input and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	
	if Input.is_action_just_pressed("night_vision"):
		toggle_night_vision()
	
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = (transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()
	if direction:
		if sprint_input:
			state_machine.travel("run")
			movement_speed = 5.0
		else:
			state_machine.travel("walk")
			movement_speed = 3.0
		velocity.x = direction.x * movement_speed
		velocity.z = direction.z * movement_speed
	else:
		velocity.x = move_toward(velocity.x, 0, 3.0)
		velocity.z = move_toward(velocity.z, 0, 3.0)
		state_machine.travel("idle")
		
	if started_shooting_input and not sprint_input:
		shoot()
	
	move_and_slide()


func cast_ray():
	var space_state = get_world_3d().direct_space_state
	var cam = camera
	var mousepos = get_viewport().get_mouse_position()

	var origin = cam.project_ray_origin(mousepos)
	var end = origin + cam.project_ray_normal(mousepos) * RAY_LENGTH
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true

	var result = space_state.intersect_ray(query)
	var collider = null
	if result:
		collider = result["collider"]
	return collider

func toggle_night_vision():
	if nv_screen.visible:
		nv_screen.hide()
		nv_light.hide()
	else:
		nv_screen.show()
		nv_light.show()
		$AudioStreamPlayer.play()


func shoot():
	state_machine.travel("shoot")
	
	var hitted_object = cast_ray()
	if hitted_object:
		if hitted_object.has_method("die"):
			hitted_object.die()
