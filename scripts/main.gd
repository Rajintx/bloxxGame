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
var wind_interval: float = 5.0 # Current random interval
var wind_duration_min: float = 5.0
var wind_duration_max: float = 12.0

var perfect_threshold: float = 5.0
var last_landed_x: float = 0.0

var block_colors: Array = [
	Color(0.9, 0.75, 0.2),
	Color(0.2, 0.75, 0.9),
	Color(0.9, 0.3, 0.3),
	Color(0.3, 0.9, 0.3),
	Color(0.7, 0.3, 0.9),
]

var block_physics_material: PhysicsMaterial

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
	process_mode = Node.PROCESS_MODE_ALWAYS
	block_physics_material = PhysicsMaterial.new()
	block_physics_material.friction = 0.8
	block_physics_material.bounce = 0.2
	
	# Ensure foundation is in the correct group
	var foundation = get_node_or_null("Foundation")
	if foundation:
		foundation.add_to_group("foundation")
		last_landed_node = foundation
		last_landed_x = foundation.global_position.x
		
	_connect_buttons()
	randomize()
	_update_wind()
	_update_ui()
	_spawn_new_block()
	
	target_camera_y = camera.position.y

func _connect_buttons() -> void:
# ... (rest of buttons)
# ... (rest of the function)
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
	
	# Smoothly move camera
	camera.position.y = lerp(camera.position.y, target_camera_y, 2.0 * delta)
	# Keep crane at top of screen
	crane.position.y = camera.position.y - 250.0

	wind_timer += delta
	if wind_timer >= wind_interval:
		_update_wind()
		wind_timer = 0.0

func _physics_process(_delta: float) -> void:
	if is_paused or is_game_over:
		return

	if is_instance_valid(current_block):
		if current_block.freeze and not block_dropped:
			current_block.global_position = block_container.global_position
		elif block_dropped:
			current_block.apply_central_force(wind_velocity * 5.0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_game_over:
			return
		_toggle_pause()
		return

	if is_paused or is_game_over or block_dropped:
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
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

func _create_block() -> RigidBody2D:
	var block = RigidBody2D.new()
	block.name = "Block"
	block.gravity_scale = 0.0
	block.linear_damp = 0.5
	block.angular_damp = 1.0
	block.freeze = true
	block.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	block.mass = 1.0
	block.contact_monitor = true
	block.max_contacts_reported = 4
	block.collision_layer = 4
	block.collision_mask = 3
	block.physics_material_override = block_physics_material

	var shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(100, 50)
	shape.shape = rect_shape
	block.add_child(shape)

	var visual = ColorRect.new()
	visual.name = "BlockVisual"
	visual.offset_left = -50.0
	visual.offset_top = -25.0
	visual.offset_right = 50.0
	visual.offset_bottom = 25.0
	visual.color = block_colors[randi() % block_colors.size()]
	block.add_child(visual)

	var notifier = VisibleOnScreenNotifier2D.new()
	notifier.name = "VisibleOnScreenNotifier2D"
	block.add_child(notifier)

	return block

func _spawn_new_block() -> void:
	if is_game_over or is_paused:
		return
	
	# Prevent multiple blocks from spawning
	if is_instance_valid(current_block):
		return

	var new_block := _create_block()
	block_container.add_child(new_block)
	new_block.global_position = block_container.global_position
	current_block = new_block
	block_dropped = false

	# Use a lambda or bind to ensure we know which block triggered the collision
	current_block.body_entered.connect(_on_block_body_entered.bind(current_block))
	var notifier = current_block.get_node("VisibleOnScreenNotifier2D")
	notifier.screen_exited.connect(_on_block_screen_exited)

func _on_block_body_entered(body: Node, block: RigidBody2D) -> void:
	if is_game_over or is_paused:
		return
	# Only process if this is the active dropped block
	if block != current_block or not block_dropped:
		return

	# Strict stacking: must touch the last landed node
	if body == last_landed_node:
		_score_block(block)
	else:
		# Touched something else (ground, wrong block, etc.)
		_game_over()

func _score_block(block: RigidBody2D) -> void:
	# Disconnect collision signal once scored
	if block.body_entered.is_connected(_on_block_body_entered.bind(block)):
		block.body_entered.disconnect(_on_block_body_entered.bind(block))

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

	block.get_parent().remove_child(block)
	tower.add_child(block)
	block.global_position = global_pos
	block.global_rotation = global_rot
	block.add_to_group("tower")

	landed_count += 1
	
	# Multiplier logic:
	# "if previous block and next block match perfectly then only multiplier will increase else it won't"
	# "if slightly misaligned then the multiplier will reset"
	var diff = abs(block.global_position.x - last_landed_x)
	var is_perfect = diff <= perfect_threshold
	
	if is_perfect:
		multiplier = min(multiplier + 1, 10)
	else:
		multiplier = 1

	score += 1 * multiplier
	last_landed_x = block.global_position.x
	last_landed_node = block
	
	# Move camera up
	target_camera_y -= 50.0
	
	_update_ui()
	block_landed.emit()

	get_tree().create_timer(0.5).timeout.connect(_spawn_new_block, CONNECT_ONE_SHOT)

func _on_block_screen_exited() -> void:
	if not is_game_over and block_dropped and not is_paused:
		_game_over()

func _update_wind() -> void:
	# Set a new random interval for the next wind change
	wind_interval = randf_range(wind_duration_min, wind_duration_max)
	
	# Initial max wind is 10, increases by 10 for every 25 blocks
	var max_wind = 10.0 + (floor(landed_count / 25.0) * 10.0)
	var strength = randf_range(0, max_wind)
	var direction = randf_range(-1.0, 1.0)
	wind_velocity = Vector2(direction * strength, 0)

	# Adjust 'Calm' threshold to be relative to current max wind
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
	
	target_camera_y = 300.0
	camera.position.y = 300.0
	
	var foundation = get_node_or_null("Foundation")
	if foundation:
		last_landed_node = foundation
		last_landed_x = foundation.global_position.x
	else:
		last_landed_node = null
		last_landed_x = 0.0

	game_over_screen.visible = false
	pause_screen.visible = false

	# Clear tower blocks
	for child in tower.get_children():
		child.queue_free()

	# Clear falling blocks
	for child in get_children():
		if child is RigidBody2D:
			child.queue_free()
			
	# Clear crane block
	for child in block_container.get_children():
		child.queue_free()

	current_block = null

	# Give a small delay for queue_free to finish
	await get_tree().process_frame
	await get_tree().process_frame

	_spawn_new_block()
	_update_wind()
	_update_ui()
