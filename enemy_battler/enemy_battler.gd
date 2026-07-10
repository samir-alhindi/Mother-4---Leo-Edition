class_name EnemyBattler extends Battler

@onready var texture_rect: Sprite2D = %TextureRect

var data: EnemyBattlerData
var tween: Tween

func _ready() -> void:
	texture_rect.texture = data.sprite

func perform_action() -> void:
	pass

func sprite_flash() -> void:
	tween = create_tween()
	tween.set_loops()
	tween.tween_property(texture_rect, "modulate:v", 7, 2)
	tween.tween_property(texture_rect, "modulate:v", 1, 1)

func stop_flash() -> void:
	tween.kill()
