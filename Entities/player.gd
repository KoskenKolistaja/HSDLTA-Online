extends CharacterBody3D
class_name Player


const JUMP_VELOCITY := 4.5
const RAY_LENGTH := 1000.0 # Adjust the distance of the raycast
const WEAPON_DEFAULT_POS = Vector3(0.03, -0.1, -0.01)
const WEAPON_AIM_POS = Vector3(-0.016, -0.079, -0.02)

## Authorative player id of player node.
@export var player_id: int
## Mouse sensitivity
@export var sensitivity: float = 0.005
## Maximum vertical rotation in degrees
@export var vertical_limit: float = 80.0 
## Bigger smooths more.
@export var camera_rot_smoothing := 0.02 
## Toggles whether mouse is captured or not.
@export var capture_mouse := true:
	set(val):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_VISIBLE
# Night vision vars
@export var nv_screen: ColorRect
@export var nv_light: SpotLight3D

# Animation variables
@export var anim_tree_outer: AnimationTree
@onready var state_machine = $AnimationTree.get("parameters/playback")
@onready var blendspace_1d: AnimationNodeBlendSpace1D   # Get BlendSpace1D node
@onready var blendspace_run: AnimationNodeBlendSpace2D 
@onready var blendspace_walk: AnimationNodeBlendSpace2D
@onready var blendspace_cwalk: AnimationNodeBlendSpace2D

@onready var camera := $HeadPivot/Camera3D

var movement_speed := 3.0
var rotation_x: float = 0.0 ## Tracks vertical rotation

# Player convenience functions, all of these use player_id
var is_local: bool: ## true if locally controlled, false if by network
	get:
		var local_pd := Net.get_local_player_or_null()
		return local_pd.player_id == player_id
var player: PlayerData:
	get:
		return Net.get_player_by_id(player_id)

# Input vars, set by controller node
var move_input: Vector2 = Vector2.ZERO
var look_input: Vector2 = Vector2.ZERO
var jump_input := false
var sprint_input := false
var crouch_input := false
var started_shooting_input := false
var shooting_input := false

# Camera smoothing variables
var look_input_smoother_tween: Tween = null
var smoothed_look_input := Vector2.ZERO
var smoothed_look_goal := Vector2.ZERO


func _ready():
	set_multiplayer_authority(player.network_id, true)
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_VISIBLE
	$HeadPivot/Camera3D/Viewmodel.position = WEAPON_AIM_POS
	blendspace_1d = anim_tree_outer.get("parameters/StateMachine")
	
	for c in get_children(true):
		if c is Camera3D and is_local:
			c.make_current()
	
	#print(anim_tree_outer.get("parameters/playback"))
	
	#print(anim_tree_outer.get("parameters/StateMachine/BlendSpace1D").get_blend_point_node(0))
	#print(anim_tree_outer)
	#print(blendspace_1d)
	#
	#blendspace_run = blendspace_1d.get_blend_point_node(0)
	#blendspace_walk = blendspace_1d.get_blend_point_node(1)
	#blendspace_cwalk = blendspace_1d.get_blend_point_node(2)

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
	
	if crouch_input:
		$HeadPivot.position.y = move_toward($HeadPivot.position.y, 0.75, 0.1)
		var new_value = move_toward(anim_tree_outer.get("parameters/BlendSpace1D/blend_position"),1,0.1)
		
		anim_tree_outer.set("parameters/BlendSpace1D/blend_position", new_value)

	else:
		$HeadPivot.position.y = move_toward($HeadPivot.position.y, 1.5, 0.1)
	
	if Input.is_action_pressed("mouse2"):
		$HeadPivot/Camera3D/Viewmodel.position = $HeadPivot/Camera3D/Viewmodel.position.move_toward(WEAPON_AIM_POS, 0.01)
	else:
		$HeadPivot/Camera3D/Viewmodel.position = $HeadPivot/Camera3D/Viewmodel.position.move_toward(WEAPON_DEFAULT_POS, 0.01)
	
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = (transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()
	if direction:
		if sprint_input:
			state_machine.travel("run")
			movement_speed = 5.0
			
			var new_value = move_toward(anim_tree_outer.get("parameters/BlendSpace1D/blend_position"),-1,0.1)
			anim_tree_outer.set("parameters/BlendSpace1D/blend_position", new_value)
		else:
			state_machine.travel("walk")
			movement_speed = 3.0
			var new_value = move_toward(anim_tree_outer.get("parameters/BlendSpace1D/blend_position"),0,0.1)
			anim_tree_outer.set("parameters/BlendSpace1D/blend_position", new_value)
			
		velocity.x = direction.x * movement_speed
		velocity.z = direction.z * movement_speed
		var blend_direction = Vector2(move_input.x, -move_input.y)
		update_animations(blend_direction)
	else:
		velocity.x = move_toward(velocity.x, 0, 3.0)
		velocity.z = move_toward(velocity.z, 0, 3.0)
		state_machine.travel("idle")
		update_animations(Vector2.ZERO)
		
	if started_shooting_input and not sprint_input:
		shoot()
	
	if Input.is_action_just_pressed("reload"):
		state_machine.travel("reload")
		print("juu")
	
	if Input.is_action_pressed("crouch") or Input.is_action_pressed("mouse2"):
		velocity *= 0.5
	
	move_and_slide()

func update_animations(blend_position: Vector2):
	var current_position = anim_tree_outer.get("parameters/BlendSpace1D/0/blend_position")
	var desired = current_position.move_toward(blend_position, 0.1)
	
	anim_tree_outer.set("parameters/BlendSpace1D/0/blend_position", desired)
	anim_tree_outer.set("parameters/BlendSpace1D/1/blend_position", desired)
	anim_tree_outer.set("parameters/BlendSpace1D/2/blend_position", desired)
	
	#blendspace_run.set_blend_point_position(0, blend_position)
	#blendspace_walk.set_blend_point_position(0, blend_position)
	#blendspace_cwalk.set_blend_point_position(0, blend_position)



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
		if hitted_object.has_method("rpc_take_damage"):
			hitted_object.rpc_take_damage.rpc(10)
