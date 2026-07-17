class_name EnemyBattler extends Battler

@onready var texture_rect: Sprite2D = %TextureRect
@onready var pre_attack_sound: AudioStreamPlayer = %PreAttackSound
@onready var damage_label: Label = %DamageLabel
@onready var dead_sound: AudioStreamPlayer = %DeadSound
@onready var hurt_sound: AudioStreamPlayer = %HurtSound
@onready var cursor: AnimatedSprite2D = %Cursor

var data: EnemyBattlerData
var tween: Tween

func _ready() -> void:
	texture_rect.texture = data.sprite
	talk_animation.position.y = -data.talk_bubble_height

func perform_action() -> void:
	pre_attack_sound.play()
	await blink()
	if is_talking:
		if battler_i_am_talking_to.is_alive:
			EventBus.display_text.emit("%s is busy talking" % battler_name)
			await EventBus.textbox_closed
			finished_performing_action.emit()
			return
		else:
			stop_talking()
	if randf() < data.chance_to_waste_turn:
		EventBus.display_text.emit(data.waste_turn_text)
		await EventBus.textbox_closed
	else:
		var living_allies := allies.filter(battler_is_alive)
		var target: AllyBattler = living_allies.pick_random()
		if not target:
			EventBus.display_text.emit("%s wanted to attack...\nBut nobody was left" % battler_name)
			await EventBus.textbox_closed
			finished_performing_action.emit()
			return
		EventBus.display_text.emit("%s attacked %s" % [battler_name, target.battler_name])
		await EventBus.textbox_closed
		await target.take_damage(offense)
	finished_performing_action.emit()

func sprite_flash() -> void:
	cursor.show()
	tween = create_tween()
	tween.set_loops()
	tween.tween_property(texture_rect.material, "shader_parameter/white_progress", 1, 1.0)
	tween.tween_property(texture_rect.material, "shader_parameter/white_progress", 0, 1.0)

func stop_flash() -> void:
	cursor.hide()
	tween.kill()
	(texture_rect.material as ShaderMaterial).set_shader_parameter("white_progress", 0.0)

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
	amount -= defense
	amount = max(amount, 1)
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
		if is_talking:
			stop_talking()
			battler_i_am_talking_to.stop_talking()
		await tween.finished

func can_talk() -> bool:
	return data.can_be_talked_to

func talk() -> void:
	is_talking = true
	talk_animation.show()
	talk_animation.play()
	tween = create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	var y := texture_rect.position.y
	tween.tween_property(texture_rect, "position:y", y+3, 0.5)
	tween.tween_property(texture_rect, "position:y", y-3, 0.5)
