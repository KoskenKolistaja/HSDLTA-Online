extends Node3D


@export var UPDATE_CD_MS := 400 # How long between updating the light values

@onready var top_vp := $TopViewport
@onready var bottom_vp := $BottomViewport
@onready var label := $Label3D

var _update_clock := Clock.new()
var _cached_light_value := 0.0


func _process(_delta: float) -> void:
	if _update_clock.measure() > UPDATE_CD_MS:
		update()
		label.text = "Light: %.2f" % get_light_level()
		#%TopTex.texture = top_vp.get_texture()
		#%BottomTex.texture = bottom_vp.get_texture()
		_update_clock.restart()


func update() -> void:
	# This function takes a few ms to run...
	var top_img := (top_vp.get_texture() as ViewportTexture).get_image()
	var bottom_img := (bottom_vp.get_texture() as ViewportTexture).get_image()
	#var black_img := Image.create_empty(top_img.get_size().x, top_img.get_size().y, true, top_img.get_format())
	#black_img.fill(Color.BLACK)
	var c := Clock.new()
	var sum: float = 0.0
	for x in top_img.get_width():
		for y in top_img.get_height():
			var p := top_img.get_pixel(x, y)
			sum += (0.299 * p.r + 0.587 * p.g + 0.114 * p.b)
	for x in bottom_img.get_width():
		for y in bottom_img.get_height():
			var p := bottom_img.get_pixel(x, y)
			sum += (0.299 * p.r + 0.587 * p.g + 0.114 * p.b)
	var avg := sum / (top_img.get_height() * top_img.get_width() * 2)
	_cached_light_value = min(avg * 2.0, 1.0)
	# Not sure how performant this is
	#_cached_light_value = (top_img.compute_image_metrics(black_img, true)["mean"] + bottom_img.compute_image_metrics(black_img, true)["mean"]) / 2.0
	print(c.measure())
	


func get_light_level() -> float:
	return _cached_light_value
