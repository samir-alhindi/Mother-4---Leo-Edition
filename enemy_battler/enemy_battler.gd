class_name EnemyBattler extends Battler

@onready var texture_rect: Sprite2D = %TextureRect
@onready var pre_attack_sound: AudioStreamPlayer = %PreAttackSound
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var data: EnemyBattlerData
var tween: Tween

func _ready() -> void:
	texture_rect.texture = data.sprite

func perform_action() -> void:
	pre_attack_sound.play()
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.set_loops(2)
	tween.tween_property(texture_rect, "modulate:a", 0, 0.1)
	tween.tween_property(texture_rect, "modulate:a", 1, 0.1)
	await tween.finished
	
	var target: AllyBattler = allies.pick_random()
	EventBus.display_text.emit("%s attacked %s" % [battler_name, target.battler_name])
	await EventBus.textbox_closed
	await target.take_damage(offense)
	finished_performing_action.emit()

func sprite_flash() -> void:
	tween = create_tween()
	tween.set_loops()
	tween.tween_property(texture_rect, "modulate:v", 7, 2)
	tween.tween_property(texture_rect, "modulate:v", 1, 1)

func stop_flash() -> void:
	tween.kill()
	texture_rect.modulate.v = 1.0

func take_damage(amount: int) -> void:
	hp -= amount
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	var og_pos := texture_rect.position.y
	tween.tween_property(texture_rect, "position:y", og_pos-10, 0.1)
	tween.tween_property(texture_rect, "position:y", og_pos, 0.2)
	await tween.finished
