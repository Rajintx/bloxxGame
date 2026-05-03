extends RigidBody2D

@export var block_color: Color = Color.WHITE

signal screen_exited(block: RigidBody2D)

func _ready() -> void:
	$BlockVisual.color = block_color
	$BlockVisual.position = Vector2(-50, -25)

	# Connect to the native RigidBody2D body_entered signal
	body_entered.connect(Callable(self, "_on_body_entered"))
	$VisibleOnScreenNotifier2D.screen_exited.connect(on_screen_exited)

func _on_body_entered(body: Node) -> void:
	# Emit custom signal or handle logic here
	pass

func on_screen_exited() -> void:
	emit_signal("screen_exited", self)
