extends RigidBody2D

@export var block_color: Color = Color.WHITE

# Array of room textures (can be AtlasTextures or standard Textures)
@export var rooms: Array[Texture2D] = []

# Target size for the block (physics and visual)
const BLOCK_SIZE = Vector2(100, 100)

# Upscale factor to make the block look bigger on screen
# 1.0 means the block will render at its actual size (100x100 pixels)
const UPSCALE_FACTOR = 1.0

@onready var sprite := $BlockVisual as Sprite2D
@onready var collision := $CollisionShape2D as CollisionShape2D

# Define the signal that main.gd expects
signal screen_exited(block: RigidBody2D)

func _ready() -> void:
	# If rooms array is empty, try to load default textures
	if rooms.is_empty():
		# Try loading AtlasTextures first
		rooms = [
			load("res://assets/rooms/room_1.tres"),
			load("res://assets/rooms/room_2.tres"),
			load("res://assets/rooms/room_3.tres")
		]
		
		# If AtlasTextures fail, try loading the raw PNG
		if rooms.is_empty() or rooms[0] == null:
			var texture = load("res://assets/rooms/room1.png")
			if texture:
				rooms = [texture]

	if rooms.size() > 0:
		var selected = rooms[randi() % rooms.size()]
		if selected == null:
			push_error("Failed to load texture")
			return
			
		sprite.texture = selected
		
		# Get the actual texture size
		var tex_size: Vector2
		if selected is AtlasTexture:
			tex_size = (selected as AtlasTexture).region.size
		else:
			tex_size = selected.get_size()
			
		_fit_texture_to_block(tex_size)
	else:
		push_error("No textures available")
		# Fallback to a default color if no texture
		if sprite:
			sprite.visible = false

	# Connect signals
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)

func _fit_texture_to_block(tex_size: Vector2) -> void:
	if sprite == null or tex_size.x == 0 or tex_size.y == 0:
		return

	# 1. Configure Sprite2D to fill the block bounds perfectly without cropping
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.region_enabled = false
	
	# 2. Scale the sprite to match the target BLOCK_SIZE
	sprite.scale = Vector2(BLOCK_SIZE.x / tex_size.x, BLOCK_SIZE.y / tex_size.y) * UPSCALE_FACTOR
	
	# 3. Center the sprite
	sprite.centered = true
	sprite.position = Vector2(0, 0)

	# 4. Update collision shape to match the block size
	if collision and collision.shape is RectangleShape2D:
		collision.shape.size = BLOCK_SIZE

func _on_body_entered(body: Node) -> void:
	pass

func _on_screen_exited() -> void:
	# Emit the custom signal expected by main.gd
	screen_exited.emit(self)
