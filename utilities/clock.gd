extends RefCounted
class_name Clock


var _start_ms: int
var started := false


func start() -> Clock:
	assert(not started)
	_start_ms = Time.get_ticks_msec()
	started = true
	return self


## Returns accrued time in ms.
func measure() -> int:
	assert(started)
	return Time.get_ticks_msec() - _start_ms


func restart() -> Clock:
	assert(started)
	_start_ms = Time.get_ticks_msec()
	return self


## Returns accrued time in ms and restarts the clock. 
func measure_and_restart() -> int:
	assert(started)
	var time := measure()
	restart()
	return time
	
