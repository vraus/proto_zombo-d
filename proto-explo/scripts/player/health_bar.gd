extends ProgressBar

@onready var timer: Timer = $Timer
@onready var damage_bar: ProgressBar = $DamageBar

var health = 0 : set = _set_health
var decay_rate := 2.0
var can_damage_decay : bool = false

func _set_health(new_health):
	var prev_health = health
	health = min(max_value, new_health)
	value = health
	
	if health <= 0:
		# queue_free()
		pass
		
	if health < prev_health:
		timer.start()
	else:
		damage_bar.value = health

func init_health(_health):
	health = _health
	max_value = _health
	value = _health
	damage_bar.max_value = _health
	damage_bar.value = _health
	
func _process(delta: float):
	if can_damage_decay:
		damage_bar.value = move_toward(damage_bar.value, health, decay_rate * delta)
		if damage_bar.value <= health:
			can_damage_decay = false
	
func _on_timer_timeout() -> void:
	can_damage_decay = true
	# damage_bar.value = health
