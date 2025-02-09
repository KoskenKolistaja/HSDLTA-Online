extends CharacterBody3D


var SPEED = 3.0

const JUMP_VELOCITY = 4.5

var RAY_LENGTH = 1000.0  # Adjust the distance of the raycast

@onready var state_machine = $AnimationTree.get("parameters/playback")

@onready var camera = $HeadPivot/Camera3D

@export var sensitivity: float = 0.005
@export var vertical_limit: float = 80.0	# Maximum vertical rotation in degrees

var rotation_x: float = 0.0	# Tracks vertical rotation

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)	# Locks the cursor

func _input(event):
	if event is InputEventMouseMotion:
		rotate_camera(event.relative)

func rotate_camera(relative_motion: Vector2):
	# Horizontal rotation (Y-axis)
	rotation_degrees.y -= relative_motion.x * sensitivity * 100
	
	# Vertical rotation (X-axis)
	rotation_x -= relative_motion.y * sensitivity * 100
	rotation_x = clamp(rotation_x, -vertical_limit, vertical_limit)
	$HeadPivot.rotation_degrees.x = rotation_x

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		if Input.is_action_pressed("sprint"):
			state_machine.travel("run")
			SPEED = 5.0
		else:
			state_machine.travel("walk")
			SPEED = 3.0
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, 3.0)
		velocity.z = move_toward(velocity.z, 0, 3.0)
		state_machine.travel("idle")
		
	if Input.is_action_just_pressed("mouse1") and not Input.is_action_pressed("sprint"):
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


func shoot():
	state_machine.travel("shoot")
	
	var hitted_object = cast_ray()
	if hitted_object:
		if hitted_object.has_method("die"):
			hitted_object.die()
