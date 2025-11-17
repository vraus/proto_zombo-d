extends CharacterBody3D

var player = null
var world = null
var _state_machine

@export_group("Motion")
@export var WALK_SPEED:float  = 0.35
@export var RUN_SPEED:float  = 2.5

@export_group("Attack")
@export var health:float   = 6
@export var basic_attack_damage :float = 1
@export var ATTACK_RANGE:float  = 1

var player_path : NodePath
var rng = RandomNumberGenerator.new()
var enraged :bool = false
var is_invincible :bool = false

# World UI
@onready var health_bar: ProgressBar = $SubViewport/HealthBar
# Animations
@onready var animation_tree: AnimationTree = $AnimationTree
# Navigation
@onready var nav_agent = $NavigationAgent3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = GameManager.player
	world = GameManager.world
	_state_machine = animation_tree.get("parameters/playback")
	
	# Roll if this Zombie is Enraged (25% chance)
	var roll_enraged = rng.randf_range(0.0, 100.0)
	if roll_enraged <= 25.0:
		enraged = true
		basic_attack_damage *= 4.0
		health *= 4.0
		invincibility_frame()
		world.unraged_zombie_spawned()
		
	health_bar.init_health(health)
	animation_tree.set("parameters/conditions/enraged", enraged)
	animation_tree.set("parameters/conditions/not_enraged", !enraged)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	velocity = Vector3.ZERO
	
	match _state_machine.get_current_node():
		"ZombieRunning":
			_follow_motion_rotation(RUN_SPEED, delta)
		"ZombieWalk":
			_follow_motion_rotation(WALK_SPEED, delta)
		"ZombieAttack":
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	
	# Condition
	animation_tree.set("parameters/conditions/attack", _target_in_range())
	animation_tree.set("parameters/conditions/run", !_target_in_range())
	
	animation_tree.get("parameters/playback")
	
	move_and_slide()
	
func _follow_motion_rotation(speed, delta):
	nav_agent.set_target_position(player.global_transform.origin)
	var next_nav_point = nav_agent.get_next_path_position()
	velocity = (next_nav_point - global_transform.origin).normalized() * speed
	rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), delta * 10.0)

func _target_in_range():
	return global_position.distance_to(player.global_position) < ATTACK_RANGE
	
func _hit_finished():
	if global_position.distance_to(player.global_position) < ATTACK_RANGE + 1.0:
		var dir = global_position.direction_to(player.global_position)
		player.hit(dir, basic_attack_damage)

func _on_area_3d_body_part_hit(dam: Variant) -> void:
	if is_invincible:
		return
		
	health -= dam
	world._on_area_3d_body_part_hit()
	health_bar.health = health
	if health <= 0:
		world.zombie_killed()
		queue_free()

func invincibility_frame():
	is_invincible = true
	await get_tree().create_timer(2.5).timeout
	is_invincible = false
