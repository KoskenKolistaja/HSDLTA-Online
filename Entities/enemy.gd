extends CharacterBody3D


@onready var nav_agent = $NavigationAgent3D
@onready var state_machine = $AnimationTree.get("parameters/playback")

const DEF_SHOOTING_ROTATION := Vector3(11.9,140.4,0.3)
const WALK_SPEED: float = 1.5
const RUN_SPEED: float = 4.0

var alert_position: Vector3
var current_time: int = 0
var target: Node3D = null
var state = STATES.IDLE

enum STATES {
	IDLE,
	ATTACKING,
	ALERT,
	DEAD
}



func _ready():
	pass

func _physics_process(delta):
	$Label3D.text = str(target)
	
	
	match state:
		STATES.IDLE:
			idle()
		STATES.ATTACKING:
			attacking()
		STATES.ALERT:
			alert()
	
	move_and_slide()


func idle():
	if current_time + 100 < Time.get_ticks_msec():
		current_time = Time.get_ticks_msec()
		check_sight()
	
	if nav_agent.is_navigation_finished():
		look_around()
	else:
		var direction = calculate_direction()
		walk(direction)
	
	if target:
		change_scene(STATES.ATTACKING)


func change_scene(new_state: STATES):
	state = new_state
	current_time = Time.get_ticks_msec()


func attacking():
	if not target:
		change_scene(STATES.ALERT)
	elif target and can_see(target):
		shoot_at(target)
		current_time = Time.get_ticks_msec()
	else:
		update_target_location(target.global_transform.origin)
		var direction_to_target = calculate_direction()
		run(direction_to_target)
		if current_time + 5000 < Time.get_ticks_msec():
			check_sight()
			current_time = Time.get_ticks_msec()


func die():
	state_machine.travel("die")
	state = STATES.DEAD


func alert():
	state_machine.travel("idle_alert")
	stand_still()


func shoot_at(object):
	var direction = (object.global_position - self.global_position).normalized()
	rotate_towards(direction)
	state_machine.travel("shoot")
	stand_still()


func can_see(object: Node3D) -> bool:
	#if not object or not object is CollisionObject3D:
		#return false
	var space_state = get_world_3d().direct_space_state
	var from = global_transform.origin
	var to = object.global_position + Vector3(0,1,0)

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self] # Exclude self to prevent self-collision

	var result = space_state.intersect_ray(query)

	if result.is_empty():
		return false # No object was detected at all

	var hit_collider = result["collider"]

	# Ensure the hit object is the target and is in layer 8
	if hit_collider == object:
		return true

	return false # Something else blocked the view


func rotate_towards(desired_orientation: Vector3):
	var vector = Vector3(desired_orientation.x, 0, desired_orientation.z).normalized()
	var forward = -global_transform.basis.z.normalized()
	
	var angle = forward.signed_angle_to(vector, Vector3.UP)
	
	rotation_degrees.y = lerp_angle(rotation_degrees.y, rotation_degrees.y + angle, 7)


func look_around():
	state_machine.travel("idle1")
	stand_still()


func stand_still():
	velocity = velocity.move_toward(Vector3.ZERO, .5)


func walk(direction: Vector3):
	state_machine.travel("walk")
	
	direction *= WALK_SPEED
	
	rotate_towards(direction)
	
	velocity = velocity.move_toward(direction, .5)


func run(direction: Vector3):
	state_machine.travel("run")
	
	direction *= RUN_SPEED
	
	rotate_towards(direction)
	
	velocity = velocity.move_toward(direction, .5)


func calculate_direction() -> Vector3:
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var new_direction = (next_location - current_location).normalized()
	
	return new_direction


func check_sight():
	var area: Area3D = $swat/Armature/Skeleton3D/BoneAttachment3D/Area3D
	var bodies = area.get_overlapping_bodies()
	if bodies:
		target = bodies[0]
	else:
		target = null


func update_target_location(target_location):
	nav_agent.target_position = target_location
	if not nav_agent.is_target_reachable():
		nav_agent.target_position = Vector3.ZERO


func _on_sight_timer_timeout():
	check_sight()


func _on_idle_timer_timeout():
	if state == STATES.IDLE and nav_agent.is_navigation_finished():
		var target_location = self.global_position + Vector3(randf_range(-10,10),0,randf_range(-10,10))
		update_target_location(target_location)
		$IdleTimer.wait_time = randf_range(3,12)
