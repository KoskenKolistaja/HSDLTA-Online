extends Control
class_name HUD


class DetectEntry:
	var node: DetectionProgress
	var last_time_updated: int
	var last_detection_level: float
	
	func _init(_node: DetectionProgress, time_ms: int, _last_detection_level: float) -> void:
		node = _node
		last_time_updated = time_ms
		last_detection_level = _last_detection_level


const DetectionProgressScene := preload("res://menus/detection_progress.tscn")
const DetectionProgress := preload("res://menus/detection_progress.gd")

var _enemy_detection_displays: Dictionary[Node3D, DetectEntry] = {}


func _process(delta: float) -> void:
	for enemy in _enemy_detection_displays:
		var time_prog := (Time.get_ticks_msec() - _enemy_detection_displays[enemy].last_time_updated) / 1000.0
		_enemy_detection_displays[enemy].node.set_detection_level(
			lerpf(_enemy_detection_displays[enemy].last_detection_level, 0, time_prog)
		)
		if Time.get_ticks_msec() - _enemy_detection_displays[enemy].last_time_updated > 1000:
			_enemy_detection_displays[enemy].node.queue_free()
			_enemy_detection_displays.erase(enemy)


func set_detection_level(enemy: Node3D, detection_level: float) -> void:
	if not _enemy_detection_displays.has(enemy):
		var scn := DetectionProgressScene.instantiate()
		$ScreenCenter.add_child(scn)
		_enemy_detection_displays[enemy] = DetectEntry.new(scn, Time.get_ticks_msec(), detection_level)
	var display: DetectionProgress = _enemy_detection_displays[enemy].node
	
	# compute angle
	var p := Net.get_local_player().get_player_node_or_null()
	var enem_pos := Vector2(enemy.global_position.x, enemy.global_position.z)
	var p_pos := Vector2(p.global_position.x, p.global_position.z)
	
	# update
	display.rotation = (enem_pos - p_pos).rotated(p.rotation.y).angle() + PI / 2.0
	display.set_detection_level(detection_level)
	_enemy_detection_displays[enemy].last_time_updated = Time.get_ticks_msec()
	_enemy_detection_displays[enemy].last_detection_level = detection_level
