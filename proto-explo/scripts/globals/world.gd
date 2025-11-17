extends Node3D

# UI
@onready var hit_rect: ColorRect = $UI/HitRect
@onready var reticule: TextureRect = %reticule
@onready var hitmarker: TextureRect = %hitmarker
@onready var numzombies_label: Label = $UI/numzombies
@onready var endgame_container: VBoxContainer = $UI/EndgameContainer
#Spawners
@onready var spawns: Node3D = $characters/Spawns
@onready var zombie_spawn_timer: Timer = $ZombieSpawnTimer
# Navigation
@onready var navigation_region_3d: NavigationRegion3D = $map/NavigationRegion3D

var zombie = load("res://scenes/zombie/zombie.tscn")
var instance
var can_spawn = false
var player = null
var zombies_to_kill :int = 15
var num_zombies :int = 0
var num_killed_zombies :int = 0

func _ready():
	GameManager.set_world(self)
	randomize()
	player = GameManager.player

func _on_player_3d_player_hit() -> void:
	hit_rect.visible = true
	await get_tree().create_timer(0.2).timeout
	hit_rect.visible = false

func _get_random_chil(parent_node):
	var random_id = randi() % parent_node.get_child_count()
	return parent_node.get_child(random_id) 

func _on_zombie_spawn_timer_timeout() -> void:
	if !can_spawn:
		return
		
	# Spawn zombie on one of the spawners
	var spawn_point = _get_random_chil(spawns).global_position
	instance = zombie.instantiate()
	instance.position = spawn_point
	navigation_region_3d.add_child(instance)
	# Randomize wait time before next zombie spawn
	var random_wait_time = randi() % 5 + 1
	zombie_spawn_timer.wait_time = random_wait_time
	# Increment zombie limit
	num_zombies += 1
	if num_zombies >= zombies_to_kill:
		can_spawn = false
		zombie_spawn_timer.stop()

func _on_area_3d_body_part_hit():
	hitmarker.visible = true
	await get_tree().create_timer(0.2).timeout
	hitmarker.visible = false

func _on_combat_zone_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		can_spawn = true
		
func zombie_killed():
	num_killed_zombies += 1
	numzombies_label.text = str(num_killed_zombies)
	if num_killed_zombies == zombies_to_kill:
		victory()

func unraged_zombie_spawned():
	hit_rect.visible = true
	await get_tree().create_timer(0.2).timeout
	hit_rect.visible = false
	await get_tree().create_timer(0.2).timeout
	hit_rect.visible = true
	await get_tree().create_timer(0.2).timeout
	hit_rect.visible = false
	player.apply_shake(2.0)
	
func _toggle_engame_ui():
	endgame_container.visible = true
	reticule.visible = false
	player.toggle_mouse_visible()

func victory():
	_toggle_engame_ui()
	
# Function to call from the player once he's dead
func lose():
	_toggle_engame_ui()

func _on_btn_leave_pressed() -> void:
	get_tree().quit()

func _on_btn_restart_pressed() -> void:
	get_tree().reload_current_scene()
