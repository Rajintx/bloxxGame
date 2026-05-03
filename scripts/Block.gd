extends RigidBody2D

@export var block_color: Color = Color.WHITE

signal screen_exited(block: RigidBody2D)

func _ready() -> void:
	# Assuming block size 64x64 on a 1536x1024 spritesheet
	var cols = 1536 / 64
	var rows = 1024 / 64
	var total_frames = cols * rows
	
	# Select random frame
	var random_frame = randi() % total_frames
	var frame_x = random_frame % cols
	var frame_y = random_frame / cols
	
	$BlockVisual.frame_coords = Vector2i(frame_x, frame_y)
	
	# Connect to the native RigidBody2D body_entered signal
	body_entered.connect(Callable(self, "_on_body_entered"))
	$VisibleOnScreenNotifier2D.screen_exited.connect(on_screen_exited)

func _on_body_entered(body: Node) -> void:
	pass

func on_screen_exited() -> void:
	emit_signal("screen_exited", self)