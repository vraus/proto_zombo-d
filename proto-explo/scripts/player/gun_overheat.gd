extends ProgressBar

@export var decay_rate := 50.0

var _can_cooldown :bool = false
var _can_shoot :bool = true

func _ready() -> void:
	value = 0.0

func _process(delta):
	if value >= 100.0:
		value = 100.0
		_can_shoot = false
		
	if _can_cooldown:
		value = move_toward(value, 0, delta * decay_rate)
		
	if value == 0.0:
		_can_cooldown = false
		_can_shoot = true

func set_heat(new_heat):
	value = new_heat

func incr_heat():
	_can_cooldown = false
	set_heat(value + 5)
	
func can_shoot() -> bool:
	return _can_shoot && !_can_cooldown
	
func reload() -> void:
	_can_cooldown = true
