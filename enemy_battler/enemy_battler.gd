class_name EnemyBattler extends Battler

@onready var texture_rect: Sprite2D = %TextureRect
@onready var pre_attack_sound: AudioStreamPlayer = %PreAttackSound
@onready var talk_animation: AnimatedSprite2D = %TalkAnimation
@onready var damage_label: Label = %DamageLabel
@onready var dead_sound: AudioStreamPlayer = %DeadSound
@onready var hurt_sound: AudioStreamPlayer = %HurtSound

var data: EnemyBattlerData
var tween: Tween

func _ready() -> void:
	texture_rect.texture = data.sprite
	talk_animation.position.y = -data.talk_bubble_height

func perform_action() -> void:
	pre_attack_sound.play()
	await blink()
	if randf() < data.chance_to_waste_turn:
		EventBus.display_text.emit(data.waste_turn_text)
		await EventBus.textbox_closed
	else:
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

func blink() -> void:
	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.set_loops(2)
	tween.tween_property(texture_rect.material, "shader_parameter/flash_alpha", 0, 0.1)
	tween.tween_property(texture_rect.material, "shader_parameter/flash_alpha", 1, 0.15)
	await tween.finished

func shake() -> void:
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(texture_rect, "rotation_degrees", -10, 0.1)
	tween.tween_property(texture_rect, "rotation_degrees", 0, 0.2)
	await tween.finished

func take_damage(amount: int, psi_damage:=false) -> void:
	damage_label.text = str(amount)
	damage_label.show()
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(damage_label, "scale", Vector2.ONE*1.2, 0.2)
	tween.tween_property(damage_label, "scale", Vector2.ONE, 0.4)
	tween.tween_property(damage_label, "visible", false, 0.01)
	
	hurt_sound.play()
	if not psi_damage:
		await shake()
	else:
		await blink()
	
	hp -= amount
	if hp <= 0:
		EventBus.display_text.emit(data.death_text)
		await EventBus.textbox_closed
		dead_sound.play()
		tween = create_tween()
		tween.tween_property(texture_rect.material, "shader_parameter/white_progress", 1.0, 0.2)
		tween.tween_property(texture_rect.material, "shader_parameter/flash_alpha", 0.0, 0.2)
		tween.set_parallel()
		tween.tween_property(talk_animation, "modulate:a", 0, 0.2)
		is_alive = false
		died.emit()
		await tween.finished

func can_talk() -> bool:
	return data.can_be_talked_to

func talk() -> void:
	is_talking = true
	talk_animation.show()
	talk_animation.play()
	tween = create_tween().set_loops()
	var y := texture_rect.position.y
	tween.tween_property(texture_rect, "position:y", y+3, 0.5)
	tween.tween_property(texture_rect, "position:y", y-3, 0.5)
