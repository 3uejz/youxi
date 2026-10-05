extends CharacterBody2D
class_name PlayerController

@export var speed: float = 150.0
var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	print("Player ready")

func _physics_process(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis(&"ui_left", &"ui_right"),
		Input.get_axis(&"ui_up", &"ui_down")
	)
	direction = input_dir.normalized() * speed
	velocity = direction
	move_and_slide()

func _on_player_pressed() -> void:
	print("Player action triggered!")

func _input(event: InputEvent) -> void:
	pass
