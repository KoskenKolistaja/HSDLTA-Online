extends Control
class_name HUD


const DetectionProgressScene := preload("res://menus/detection_progress.tscn")
const DetectionProgress := preload("res://menus/detection_progress.gd")

var _enemy_detection_displays: Dictionary[Node3D, DetectionProgress] = {}


func set_detection_level(enemy: Node3D, detection_level: float) -> void:
	if not _enemy_detection_displays.has(enemy):
		var scn := DetectionProgressScene.instantiate()
		$ScreenCenter.add_child(scn)
		_enemy_detection_displays[enemy] = scn
	elif detection_level == 0.0 and _enemy_detection_displays.has(enemy):
		_enemy_detection_displays[enemy].queue_free()
		_enemy_detection_displays.erase(enemy)
		return
	var display := _enemy_detection_displays[enemy]
	
	# compute angle
	var p := Net.get_local_player().get_player_node_or_null()
	var enem_pos := Vector2(enemy.global_position.x, enemy.global_position.z)
	var p_pos := Vector2(p.global_position.x, p.global_position.z)
	
	# update
	display.rotation = (enem_pos - p_pos).rotated(p.rotation.y).angle()
	display.set_detection_level(detection_level)
