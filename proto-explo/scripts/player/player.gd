extends CharacterBody3D

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export_range(0.0, 1.0) var mouse_aim_sensitivity := 0.1

@export_group("Camera Shake")
@export var random_strength: float = 1.0
@export var shake_fade: float = 20.0
var rnd = RandomNumberGenerator.new()
var shake_strength: float = 0.0

@export_group("Movement")
@export var move_speed := 3.0
@export var run_speed := 5.0
@export var acceleration := 100.0
@export var rotation_speed := 12.0

@export_group("Damageable")
@export_range(1.0, 10.0) var player_health : float = 10.0
@export var hit_stagger := 8.0

var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK
var _sprint_input
var _aim_input
var _shoot_input
var curr_sensi
var _is_dead :bool = false

# Signals
signal player_hit

# Bullets
var bullet = load("res://scenes/gun/bullet.tscn")
var bullet_instance

# UI
@onready var health_bar: ProgressBar = $Player_UI/HealthBar
@onready var alert_reload: Label = %AlertReload
# Camera
@onready var camera_pivot: Node3D = %CameraPivot
@onready var camera_3d: Camera3D = %Camera3D
# Player
@onready var player: Node3D = %player
@onready var animation_tree: AnimationTree = $player/AnimationTree
# Physics
@onready var physical_bone_simulator_3d: PhysicalBoneSimulator3D = $player/Armature/Skeleton3D/PhysicalBoneSimulator3D
# Gun
@onready var gun_animation = $player/Armature/Skeleton3D/HandGun/gun/AnimationPlayer
@onready var ray_cast_3d: RayCast3D = %RayCast3D
@onready var gun_overheat: ProgressBar = %GunOverheat
# Aim
@onready var aim_ray: RayCast3D = %AimRay
@onready var aim_mesh: MeshInstance3D = %AimMesh
@onready var aim_look_at: LookAtModifier3D = $player/Armature/Skeleton3D/LookAtModifier3D
# AudioKinetic
@onready var ak_event_shoot: AkEvent3D = $AkBank/AkEvent_Shoot
@onready var ak_event_run: AkEvent3D = $AkBank/AkEvent_Run
@onready var ak_event_walk: AkEvent3D = $AkBank/AkEvent_Walk

func _ready():
	GameManager.set_player(self)
	curr_sensi = mouse_sensitivity
	health_bar.init_health(player_health)

func _input(event: InputEvent) -> void:
	if _is_dead:
		return 
		
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_aim_input = Input.is_action_pressed("right_click")
	_shoot_input = Input.is_action_pressed("left_click")
	
	if Input.is_action_pressed("reload"):
		gun_overheat.reload()
		alert_reload.visible = false

func _unhandled_input(event: InputEvent) -> void:
	var is_camera_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion: 
		_camera_input_direction = event.screen_relative * mouse_sensitivity

func _process(delta: float) -> void:
	if shake_strength > 0 :
		shake_strength = lerpf(shake_strength, 0, shake_fade * delta)
		camera_3d.v_offset = random_offset()

func _physics_process(delta: float) -> void:
	var curr_speed := move_speed
	
	# Vertical rotation of the camera
	camera_pivot.rotation.x += _camera_input_direction.y * delta * curr_sensi
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/6.0, PI/3.0)
	# Horizontal rotation of the camera
	camera_pivot.rotation.y -= _camera_input_direction.x * delta * curr_sensi
	
	# Reset the input direction to stop rotating when no input are detected
	_camera_input_direction = Vector2.ZERO
	
	# Character movements & rotations given the rotation of the camera
	var raw_input := Input.get_vector("left", "right", "forward", "backward")
	_sprint_input = Input.is_action_pressed("sprint")
	var forward := camera_3d.global_basis.z
	var right := camera_3d.global_basis.x
	
	if _sprint_input:
		curr_speed = run_speed
	if _aim_input:
		curr_speed /= 2
		curr_sensi = mouse_aim_sensitivity
	
	var move_direction := forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0
	move_direction = move_direction.normalized()
	
	velocity = velocity.move_toward(move_direction * curr_speed, acceleration * delta)
	move_and_slide()
	
	if !_aim_input:
		aim_look_at.active = false
		curr_sensi = mouse_sensitivity
		
	# Connect the model rotations to movement input
	if _aim_input: # Follow the rotation of the mouse while aiming
		var target_yaw := camera_pivot.global_rotation.y
		player.global_rotation.y = target_yaw
		ray_cast_3d.look_at(aim_mesh.global_position)
		aim_look_at.active = true
	else: # Follow rotation of the movement input otherwise
		if move_direction.length() > 0.2:
			_last_movement_direction = move_direction
		var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
		player.global_rotation.y = lerp_angle(player.rotation.y, target_angle, rotation_speed * delta)
	
	# Animate the player using speed
	update_anim_tree()
	
	# Detect whenever the player input to aim
	if _aim_input && _shoot_input && gun_overheat.can_shoot():
		shoot()

func update_anim_tree():
	var is_moving = velocity.length()
	var not_is_moving = 0.0 if (is_moving > 0) else 1.0
	animation_tree["parameters/Walk/blend_amount"] = clampf(is_moving, 0, 1)
	
	var is_sprinting = 0.0 if (!_sprint_input) else 1.0
	animation_tree["parameters/Run/blend_amount"] = clampf(is_sprinting * is_moving, 0, 1)
	
	var is_aiming = 0.0 if (!_aim_input) else 1.0
	animation_tree["parameters/AimIdle/blend_amount"] = clampf(is_aiming * not_is_moving, 0, 1)
	animation_tree["parameters/AimWalk/blend_amount"] = clampf(is_aiming * is_moving, 0, 1)

func shoot():
	if gun_animation.is_playing():
		return
		
	gun_animation.play("shoot")
	ak_event_shoot.post_event()
	bullet_instance = bullet.instantiate()
	bullet_instance.position = ray_cast_3d.global_position
	bullet_instance.transform.basis = ray_cast_3d.global_transform.basis
	get_parent().add_child(bullet_instance)
	check_aim_ray_hit()
	gun_overheat.incr_heat()
	
	if gun_overheat.value >= 90.0:
		alert_reload.visible = true
		
func check_aim_ray_hit():
	if aim_ray.is_colliding():
		if is_instance_valid(aim_ray.get_collider()):
			var collider = aim_ray.get_collider()
			var hit_position = aim_ray.get_collision_point()
			if !collider.is_in_group("enemy"):
				return 
				
			var distance = global_position.distance_to(hit_position)
			
			var projectile_speed = 80.0
			var delay = distance / projectile_speed
			
			var timer = get_tree().create_timer(delay)
			timer.timeout.connect(
				func():
				if is_instance_valid(collider):
					collider.hit()
			)

func hit(dir, dam: float):
	emit_signal("player_hit")
	player_health -= dam
	health_bar.health = player_health
	velocity += dir * hit_stagger
	apply_shake(dam)
	if player_health <= 0.0:
		player_dies()
	
func toggle_mouse_visible():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
func player_dies():
	# Activate lose condition
	GameManager.world.lose()
	# Simulate Ragdoll
	physical_bone_simulator_3d.active = true
	physical_bone_simulator_3d.physical_bones_start_simulation()
	# Avoid any inputs while dead
	_is_dead = true
	# Show mouse to use UI or close the window
	toggle_mouse_visible()

func apply_shake(dam):
	shake_strength = random_strength * dam
	
func random_offset() -> float:
	return rnd.randf_range(-shake_strength, shake_strength)

# AudioKinetic Functions

func play_walk_akevent():
	ak_event_walk.post_event()
	
func play_run_akevent():
	ak_event_run.post_event()
