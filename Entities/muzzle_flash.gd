extends GPUParticles3D


@rpc("any_peer","call_local")
func flash():
	var omni_light = $MuzzleFlashLight
	var tween = create_tween()
	tween.tween_property(omni_light, "omni_range", 0.0, 0.05)  # 1.0 is duration in seconds
	$MuzzleFlashLight.omni_range = 10
	emitting = true
