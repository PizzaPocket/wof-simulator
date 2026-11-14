extends RefCounted
## A short muscular acceleration/braking envelope, including mid-fold reversals.
var velocity: float = 0.0


func step(current: float, target: float, delta: float, seconds: float) -> float:
	var error := target - current
	var rate := 1.0 / maxf(seconds, 0.05)
	var acceleration := rate / 0.1
	var desired := signf(error) * minf(rate, sqrt(2.0 * acceleration * absf(error)))
	velocity = move_toward(velocity, desired, acceleration * delta)
	var movement := velocity * delta
	if movement * error >= 0.0 and absf(movement) >= absf(error):
		velocity = 0.0
		return target
	var next := clampf(current + movement, 0.0, 1.0)
	if next == 0.0 or next == 1.0:
		velocity = 0.0
	return next
