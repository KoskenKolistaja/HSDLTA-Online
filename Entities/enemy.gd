extends CharacterBody3D

const BulletScene := preload("res://Entities/bullet.tscn")

@onready var nav_agent := $NavigationAgent3D
@onready var state_machine: AnimationNodeStateMachinePlayback = $AnimationTree.get("parameters/playback")
@onready var syncer: MultiplayerSynchronizer = $MultiplayerSynchronizer

@export var muzzle_flash: GPUParticles3D


const DEF_SHOOTING_ROTATION := Vector3(11.9, 140.4, 0.3)
const WALK_SPEED: float = 1.5
const RUN_SPEED: float = 4.0
const FAR_DIST := 8.0  # The distance at which rep interval is changed
const REP_INTERVAL_FAR := 0.5
const REP_INTERVAL_NEAR := 0.0

var alert_position: Vector3
var current_time: int = 0
var target: Node3D = null
var state := STATES.IDLE

var tested_players: Dictionary[Player, float] = {} 

var known_issues = []

enum STATES { IDLE, ATTACKING, ALERT, DEAD }


func acknowledge():
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
	
	
	
	handle_detection()
	# Only sync frequently once a player is near the enemy.
	#if Net.is_server:
	#var shortest_dist: float = Player.instances.map(func(p: Player):
	#return p.global_position.distance_squared_to(self.global_position)
	#).min()
	#if shortest_dist > FAR_DIST:
	#syncer.replication_interval = REP_INTERVAL_FAR
	#else:
	#syncer.replication_interval = REP_INTERVAL_NEAR


func handle_detection():
	if tested_players:
		for player in tested_players:
			if not is_instance_valid(player):
				# This could be handled with a callback
				tested_players.erase(player)
				return
			var hit_number = cast_4_rays_to(player)
			var detection_multiplier = player.get_detectibility()*4
			var increase = hit_number * detection_multiplier * 0.01
			if increase == 0:
				increase = -0.001
			if state_machine.get_current_node() == "die":
				increase = -0.02
			tested_players[player] += increase
			var hud = get_tree().get_first_node_in_group("hud")
			tested_players[player] = clamp(tested_players[player],0.0,1.0)
			
			if player.is_local:
				if not tested_players[player] == 0:
					if not state == STATES.DEAD:
						hud.set_detection_level(self, tested_players[player])
			
			if tested_players[player] >= 0.95:
				if multiplayer.is_server() and not target:
					update_target.rpc(player.get_instance_id())
					target = player
			elif tested_players[player] <= 0:
				tested_players.erase(player)

@rpc("any_peer","call_remote")
func update_target(encoded_id):
	print("yritettiin päivittää target")
	var my_node = instance_from_id(encoded_id) as Node3D
	target = my_node


func cast_4_rays_to(object: Node3D) -> int:
	var object_position = object.global_position
	var sight_position = $RayCastPosition.global_position
	
	var first_position = object_position + Vector3(0,0.1,0)
	var second_position = object_position + Vector3(0.05,1,0.05)
	var third_position = object_position + Vector3(0.05,1,0.05)
	var fourth_position = object_position + Vector3(0,1.25,0)
	
	var rays = []
	
	var hit_number = 0
	
	rays.append(cast_ray(sight_position,first_position))
	rays.append(cast_ray(sight_position,second_position))
	rays.append(cast_ray(sight_position,third_position))
	rays.append(cast_ray(sight_position,fourth_position))
	
	for item in rays:
		if item == object:
			hit_number += 1
	hit_number *= 0.25
	
	return hit_number
	


func cast_ray(from,to):
	var space_state = get_world_3d().direct_space_state
	var origin = from
	var end = to
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = false
	var result = space_state.intersect_ray(query)
	var collider = null
	if result:
		collider = result["collider"]
	return collider


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
		change_state(STATES.ATTACKING)


func change_state(new_state: STATES):
	if multiplayer.is_server():
		state = new_state
		update_state.rpc(new_state)
	current_time = Time.get_ticks_msec()

@rpc("any_peer","call_remote")
func update_state(new_state):
	state = new_state

@rpc("authority", "call_remote")
func update_animation_state(target_state: String):
	state_machine.travel(target_state)

func attacking():
	if not target:
		change_state(STATES.ALERT)
	elif target and can_see(target):
		aim_at(target)
		current_time = Time.get_ticks_msec()
	else:
		update_target_location(target.global_transform.origin)
		var direction_to_target = calculate_direction()
		run(direction_to_target)
		if current_time + 5000 < Time.get_ticks_msec():
			check_sight()
			current_time = Time.get_ticks_msec()


func take_damage(amount: int) -> void:
	if not Net.is_server:
		return
	_die()


func _die():
	if multiplayer.is_server():
		state_machine.travel("die")
		update_animation_state.rpc("die")
	
	state = STATES.DEAD
	velocity = Vector3.ZERO
	$SpotLight3D.hide()


func alert():
	#if current_time + 100 < Time.get_ticks_msec():
	#current_time = Time.get_ticks_msec()
	#check_sight()

	if nav_agent.is_navigation_finished():
		stand_still()
		if multiplayer.is_server():
			state_machine.travel("idle_alert")
			update_animation_state.rpc("idle_alert")
	else:
		var direction = calculate_direction()
		walk(direction)

	if target:
		change_state(STATES.ATTACKING)

	if current_time + 30000 < Time.get_ticks_msec():
		change_state(STATES.IDLE)


func aim_at(object):
	var direction = (object.global_position - self.global_position).normalized()
	rotate_towards(direction)
	if multiplayer.is_server():
		state_machine.travel("shoot")
		update_animation_state.rpc("shoot")
	stand_still()
	
	if multiplayer.is_server():
		shoot(object)
	muzzle_flash.flash.rpc() # This should be called from the animation, no?


func shoot(object):
	#var bullet := BulletScene.instantiate() as Node3D
	#bullet.position = muzzle_flash.global_position
	#bullet.rotation = muzzle_flash.global_rotation
	#BulletManager.instance.spawn_bullet(bullet)
	
	pass
	
	#var body = cast_ray(muzzle_flash.global_position,object.global_position)
	#if body:
		#if body.is_in_group("damageable"):
			#body.rpc_take_damage.rpc(10)
	

func can_see(object: Node3D) -> bool:
	var space_state = get_world_3d().direct_space_state
	var from = $RayCastPosition.global_position
	var to = object.global_position

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]  # Exclude self to prevent self-collision

	var result = space_state.intersect_ray(query)

	if result.is_empty():
		return false  # No object was detected at all

	var hit_collider = result["collider"]

	# Ensure the hit object is the target and is in layer 8
	if hit_collider == object:
		return true

	return false  # Something else blocked the view


func rotate_towards(desired_orientation: Vector3):
	var vector = Vector3(desired_orientation.x, 0, desired_orientation.z).normalized()
	var forward = -global_transform.basis.z.normalized()

	var angle = forward.signed_angle_to(vector, Vector3.UP)

	rotation_degrees.y = lerp_angle(rotation_degrees.y, rotation_degrees.y + angle, 7)


func look_around():
	if multiplayer.is_server():
		state_machine.travel("idle1")
		update_animation_state.rpc("idle1")
		stand_still()


func stand_still():
	velocity = velocity.move_toward(Vector3.ZERO, .5)


func walk(direction: Vector3):
	if state == STATES.ALERT:
		if multiplayer.is_server():
			state_machine.travel("walk_alert")
			update_animation_state.rpc("walk_alert")
	else:
		if multiplayer.is_server():
			state_machine.travel("walk")
			update_animation_state.rpc("walk")

	direction *= WALK_SPEED

	rotate_towards(direction)

	velocity = velocity.move_toward(direction, .5)


func run(direction: Vector3):
	if multiplayer.is_server():
		state_machine.travel("run")
		update_animation_state.rpc("run")

	direction *= RUN_SPEED

	rotate_towards(direction)

	velocity = velocity.move_toward(direction, .5)


func calculate_direction() -> Vector3:
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var new_direction = (next_location - current_location).normalized()

	return new_direction


func check_sight():
	pass
	#var area: Area3D = $swat/Armature/Skeleton3D/BoneAttachment3D/Area3D
	#var bodies = area.get_overlapping_bodies()
	#if bodies:
		#target = bodies[0]
	#else:
		#target = null


func update_target_location(target_location):
	nav_agent.target_position = target_location
	if not nav_agent.is_target_reachable():
		nav_agent.target_position = Vector3.ZERO


func _on_sight_timer_timeout():
	check_sight()


func _on_idle_timer_timeout():
	if state == STATES.IDLE or state == STATES.ALERT and nav_agent.is_navigation_finished():
		var target_location = (
			self.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
		)
		update_target_location(target_location)
		$IdleTimer.wait_time = randf_range(3, 12)


func _on_detection_zone_body_entered(body):
	if body is Player:
		tested_players[body] = 0.01
