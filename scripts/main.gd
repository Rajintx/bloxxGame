extends Node2D

signal block_landed

var score: int = 0
var multiplier: int = 1
var is_game_over: bool = false
var is_paused: bool = false
var landed_count: int = 0
var block_dropped: bool = false

var crane_speed: float = 2.5
var crane_range: float = 200.0
var crane_angle: float = 0.0
var crane_base_x: float = 400.0

var wind_velocity: Vector2 = Vector2.ZERO
var wind_timer: float = 0.0
var wind_interval: float = 5.0
var wind_duration_min: float = 5.0
var wind_duration_max: float = 12.0

var perfect_threshold: float = 20.0  # Scaled up for larger blocks
var last_landed_x: float = 0.0
var last_landed_blocks: Array = []
var tilt_threshold_degrees: float = 15
var tilted_block_count: int = 0
var tower_collapsing: bool = false

var camera_lerp_speed: float = 0.8
var camera_y_offset_from_block: float = 150.0
var camera_zoom: float = 1.0  # Add camera zoom variable

var block_colors: Array = [
	Color(0.9, 0.75, 0.2),
	Color(0.2, 0.75, 0.9),
	Color(0.9, 0.3, 0.3),
	Color(0.3, 0.9, 0.3),
	Color(0.7, 0.3, 0.9),
]

var block_physics_material: PhysicsMaterial
const BLOCK_FRICTION: float = 0.8
const BLOCK_BOUNCE: float = 0.2

@onready var camera: Camera2D = $Camera2D
@onready var crane: Node2D = $Crane
@onready var block_container: Node2D = $Crane/BlockContainer
@onready var tower: Node2D = $Tower
@onready var score_label: Label = $UI/ScoreLabel
@onready var multiplier_label: Label = $UI/MultiplierLabel
@onready var wind_label: Label = $UI/WindLabel
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var pause_screen: Control = $UI/PauseScreen

var current_block: RigidBody2D = null
var last_landed_node: Node = null
var target_camera_y: float = 300.0

func _ready() -> void:
	print("Main.gd _ready() called")
	process_mode = Node.PROCESS_MODE_ALWAYS

	var foundation = get_node_or_null("Foundation")
	if foundation:
		foundation.add_to_group("foundation")
		last_landed_node = foundation
		last_landed_x = foundation.global_position.x
		print("Foundation position: ", foundation.global_position)

	_connect_buttons()
	randomize()
	_update_wind()
	_update_ui()
	_spawn_new_block()

	target_camera_y = last_landed_node.global_position.y - camera_y_offset_from_block
	 
	
	# Set camera zoom to maintain consistent view
	camera.zoom = Vector2(camera_zoom, camera_zoom)

func _connect_buttons() -> void:
	var go_restart = game_over_screen.get_node_or_null("RestartButton")
	if go_restart:
		go_restart.pressed.connect(_on_game_over_restart_pressed)
	var resume_btn = pause_screen.get_node_or_null("ResumeButton")
	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	var restart_btn = pause_screen.get_node_or_null("RestartButton")
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)

func _process(delta: float) -> void:
	if is_paused or is_game_over:
		return

	crane_angle += crane_speed * delta
	crane.position.x = crane_base_x + sin(crane_angle) * crane_range

	camera.position.y = lerp(camera.position.y, target_camera_y, camera_lerp_speed * delta)
	crane.position.y = camera.position.y - 250.0
	
	# Ensure camera zoom is maintained
	camera.zoom = Vector2(camera_zoom, camera_zoom)

	wind_timer += delta
	if wind_timer >= wind_interval:
		_update_wind()
		wind_timer = 0.0

func _physics_process(_delta: float) -> void:
	if is_paused or is_game_over or tower_collapsing:
		return

	if is_instance_valid(current_block):
		if current_block.freeze and not block_dropped:
			current_block.global_position = block_container.global_position
		elif block_dropped:
			current_block.apply_central_force(wind_velocity * 5.0)

	_check_tilt()
	 

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_game_over:
			return
		_toggle_pause()
		return

	if is_paused or is_game_over or tower_collapsing or block_dropped:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("drop_block") or (event is InputEventMouseButton and event.pressed):
		_release_block()

func _release_block() -> void:
	if not is_instance_valid(current_block) or not current_block.freeze:
		return

	var global_pos = current_block.global_position
	var global_rot = current_block.global_rotation

	current_block.get_parent().remove_child(current_block)
	add_child(current_block)
	current_block.global_position = global_pos
	current_block.global_rotation = global_rot

	block_dropped = true
	current_block.freeze = false
	current_block.linear_velocity = Vector2(wind_velocity.x * 0.5, 0)
	current_block.gravity_scale = 1.0

func _spawn_new_block() -> void:
	if is_game_over or is_paused or tower_collapsing:
		return

	if is_instance_valid(current_block):
		return

	var new_block := load("res://scenes/Block.tscn").instantiate() as RigidBody2D
	new_block.block_color = block_colors[landed_count % block_colors.size()]
	block_container.add_child(new_block)
	new_block.global_position = block_container.global_position
	current_block = new_block
	block_dropped = false

	current_block.body_entered.connect(Callable(self, "_on_block_body_entered").bind(current_block))
	current_block.screen_exited.connect(Callable(self, "_on_block_screen_exited").bind(current_block))

func _on_block_body_entered(body: Node, block: RigidBody2D) -> void:
	if is_game_over or is_paused:
		return
	if block != current_block or not block_dropped:
		return

	if body == last_landed_node:
		call_deferred("_score_block", block)
	else:
		print("DEBUG: Block touched invalid body. Triggering game over.")
		_game_over()

func _score_block(block: RigidBody2D) -> void:
	# Save the rotation at landing time before we zero it out
	var landing_rotation = block.global_rotation
	block.set_meta("landed_rotation", landing_rotation)

	block_dropped = false
	current_block = null

	block.freeze = true
	block.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	block.linear_velocity = Vector2.ZERO
	block.angular_velocity = 0.0
	block.gravity_scale = 0.0
	block.collision_layer = 2
	block.collision_mask = 3

	var global_pos = block.global_position
	var global_rot = block.global_rotation

	call_deferred("_reparent_block_to_tower", block, global_pos, global_rot)

	landed_count += 1

	var diff = abs(block.global_position.x - last_landed_x)
	var is_perfect = diff <= perfect_threshold

	if is_perfect:
		multiplier = min(multiplier + 1, 10)
	else:
		multiplier = 1

	score += 1 * multiplier
	last_landed_x = block.global_position.x
	last_landed_node = block

	last_landed_blocks.append(block)
	if last_landed_blocks.size() > 3:
		last_landed_blocks.remove_at(0)

	_check_tilt()

	target_camera_y = block.global_position.y - camera_y_offset_from_block

	_update_ui()
	block_landed.emit()

	get_tree().create_timer(0.5).timeout.connect(_spawn_new_block, CONNECT_ONE_SHOT)

func _check_tilt() -> void:
	if tower_collapsing:
		return
	if last_landed_blocks.size() < 3:
		return

	var cumulative_lean: float = 0.0

	for i in range(last_landed_blocks.size() - 1, -1, -1):
		var block = last_landed_blocks[i]
		if is_instance_valid(block):
			var rot = rad_to_deg(block.get_meta("landed_rotation", 0.0))
			cumulative_lean += rot
			print("Cumulative lean",cumulative_lean)
 			

	if abs(cumulative_lean) >= tilt_threshold_degrees:
		print("DEBUG: Cumulative lean too high. Starting tower collapse.")
		_start_tower_collapse()
				
func _reparent_block_to_tower(block: RigidBody2D, global_pos: Vector2, global_rot: float) -> void:
	if not is_instance_valid(block):
		return
	block.get_parent().remove_child(block)
	tower.add_child(block)
	block.global_position = global_pos
	block.global_rotation = global_rot
	block.add_to_group("tower")
func _start_tower_collapse() -> void:
	tower_collapsing = true

	if is_instance_valid(current_block):
		current_block.freeze = true
		current_block.linear_velocity = Vector2.ZERO
		current_block.angular_velocity = 0.0

	var original_position = tower.position
	var shake_duration := 0.6
	var shake_intensity := 5.0
	var shake_timer := 0.0

	while shake_timer < shake_duration:
		var elapsed = get_process_delta_time()
		shake_timer += elapsed
		var current_intensity = shake_intensity * (1.0 - shake_timer / shake_duration)
		tower.position.x = original_position.x + randf_range(-current_intensity, current_intensity)
		await get_tree().process_frame
	tower.position = original_position

	for child in tower.get_children():
		if child is RigidBody2D:
			child.freeze = false
			child.gravity_scale = 1.0
			child.collision_layer = 4
			child.collision_mask = 1
			child.apply_central_force(Vector2(randf_range(-200, 200), randf_range(-100, 50)))
			child.apply_torque_impulse(randf_range(-500, 500))

	await get_tree().create_timer(1.5).timeout
	_game_over()

func _on_block_screen_exited(block_that_exited: RigidBody2D) -> void:
	if not is_game_over and not is_paused:
		if block_that_exited == current_block and block_dropped:
			print("DEBUG: Active block exited screen. Triggering game over.")
			_game_over()
		elif last_landed_blocks.has(block_that_exited):
			print("DEBUG: Landed block exited screen. Triggering game over.")
			_game_over()
		else:
			print("DEBUG: Non-critical block exited screen.")

func _update_wind() -> void:
	wind_interval = randf_range(wind_duration_min, wind_duration_max)

	var every_x_block = 10.0
	var max_wind = 10.0 + (floor(landed_count / every_x_block) * 10.0)
	var strength = randf_range(0, max_wind)
	var direction = randf_range(-1.0, 1.0)
	wind_velocity = Vector2(direction * strength, 0)

	if abs(wind_velocity.x) < (max_wind * 0.2):
		wind_label.text = "Wind: Calm"
	elif wind_velocity.x > 0:
		wind_label.text = "Wind: >> %d" % int(wind_velocity.x)
	else:
		wind_label.text = "Wind: << %d" % int(abs(wind_velocity.x))

func _update_ui() -> void:
	score_label.text = "Score: %d" % score
	multiplier_label.text = "Multiplier: %dx" % multiplier

func _game_over() -> void:
	print("DEBUG: _game_over() called.")
	is_game_over = true
	game_over_screen.visible = true
	if is_instance_valid(current_block):
		current_block.freeze = true
		current_block.linear_velocity = Vector2.ZERO
		current_block.angular_velocity = 0.0

func _toggle_pause() -> void:
	if is_game_over:
		return
	is_paused = !is_paused
	get_tree().paused = is_paused
	pause_screen.visible = is_paused

func _on_resume_pressed() -> void:
	is_paused = false
	get_tree().paused = false
	pause_screen.visible = false

func _on_restart_pressed() -> void:
	get_tree().paused = false
	is_paused = false
	pause_screen.visible = false
	_restart_game()

func _on_game_over_restart_pressed() -> void:
	_restart_game()

func _restart_game() -> void:
	score = 0
	multiplier = 1
	is_game_over = false
	landed_count = 0
	crane_angle = 0.0
	wind_timer = 0.0
	block_dropped = false
	tilted_block_count = 0
	tower.position = Vector2.ZERO
	tower_collapsing = false

	last_landed_blocks.clear()

	var foundation = get_node_or_null("Foundation")
	if foundation:
		last_landed_node = foundation
		last_landed_x = foundation.global_position.x
		target_camera_y = last_landed_node.global_position.y - camera_y_offset_from_block
	else:
		last_landed_node = null
		last_landed_x = 0.0
		target_camera_y = 300.0

	camera.position.y = target_camera_y
	
	# Ensure camera zoom is maintained
	camera.zoom = Vector2(camera_zoom, camera_zoom)
	
	# Ensure camera zoom is maintained
	camera.zoom = Vector2(camera_zoom, camera_zoom)

	game_over_screen.visible = false
	pause_screen.visible = false

	for child in tower.get_children():
		child.queue_free()

	for child in get_children():
		if child is RigidBody2D:
			child.queue_free()

	for child in block_container.get_children():
		child.queue_free()

	current_block = null

	await get_tree().process_frame
	await get_tree().process_frame

	_spawn_new_block()
	_update_wind()
	_update_ui()
