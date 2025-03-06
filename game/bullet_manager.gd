extends Node3D
class_name BulletManager


## Can be used from any node: 
## BulletManager.instance.add_child(bullet)
static var instance: BulletManager

const BulletScene := preload("res://Entities/bullet.tscn")


func _ready() -> void:
	instance = self


func _exit_tree() -> void:
	instance = null if instance == self else instance # reset


func spawn_bullet(bullet: Node3D) -> void:
	rpc_spawn_bullet.rpc(bullet.position, bullet.rotation)


@rpc("any_peer", "call_local")
func rpc_spawn_bullet(pos: Vector3, rot: Vector3) -> void:
	var bullet: Node3D = BulletScene.instantiate()
	bullet.position = pos
	bullet.rotation = rot
	add_child(bullet)
