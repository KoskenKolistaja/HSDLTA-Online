extends Node3D

## Spawned by entities when shooting. Responsible for both visualizing 
## the bullet and damaging the target on hit

@export var damage: int = 10
@export var speed: float = 200.0 ## m/s
@export var max_range: float = 250

@onready var _visual: Node3D = $Visual
@onready var _bullet_mesh_instance := $Visual/BulletMesh
@onready var _bullet_mesh: TubeTrailMesh = $Visual/BulletMesh.mesh
@onready var _raycast := $RayCast3D
@onready var _start_clock := Clock.new()


func _physics_process(delta: float) -> void:
	var dist := speed * delta * 60 * (_start_clock.measure() * 0.001)
	if dist >= max_range:
		queue_free()
	_bullet_mesh_instance.position.y = -min(dist / 2.0, speed / 8.0)
	_bullet_mesh.section_length = min(dist / 2.0, 2.4)
	_raycast.target_position.y = dist
	_visual.position.y = dist
	if _raycast.is_colliding():
		var col: Node = _raycast.get_collider()
		if Net.is_server and col.is_in_group("damageable"):
			col.take_damage(damage)
		# TODO spawn decal
		queue_free()
