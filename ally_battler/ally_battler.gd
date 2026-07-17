class_name AllyBattler extends Battler

signal finished_deciding_action

@onready var bash_button: TextureButton = %BashButton
@onready var name_label: Label = %NameLabel
@onready var ui: CanvasLayer = %Ui
@onready var psi_button: TextureButton = %PsiButton
@onready var talk_button: TextureButton = %TalkButton
@onready var button_focus_sound: AudioStreamPlayer = %ButtonFocusSound
@onready var buttons: HBoxContainer = %Buttons
@onready var button_pressed_sound: AudioStreamPlayer = %ButtonPressedSound
@onready var hp_ones_place: AnimatedSprite2D = %HpOnesPlace
@onready var hp_tens_place: AnimatedSprite2D = %HpTensPlace
@onready var hp_hundreds_place: AnimatedSprite2D = %HpHundredsPlace
@onready var hud_back_ground: TextureRect = %HudBackGround
@onready var pre_attack_sound: AudioStreamPlayer = %PreAttackSound
@onready var hud: Control = %HUD
@onready var hit_sound: AudioStreamPlayer = %HitSound
@onready var hurt_sound: AudioStreamPlayer = %HurtSound
@onready var psi_animation: AnimatedSprite2D = %PsiAnimation
@onready var pre_psi_sound: AudioStreamPlayer = %PrePsiSound
@onready var psi_sound: AudioStreamPlayer = %PsiSound
@onready var talk_sound: AudioStreamPlayer = %TalkSound
@onready var damage_label: Label = %DamageLabel
@onready var pp_ones_place: AnimatedSprite2D = %PpOnesPlace
@onready var pp_tens_place: AnimatedSprite2D = %PpTensPlace
@onready var pp_hundreds_place: AnimatedSprite2D = %PpHundredsPlace
@onready var pp_odometers: Array[AnimatedSprite2D] = [
	pp_ones_place,
	pp_tens_place,
	pp_hundreds_place
]
@onready var cancel_sound: AudioStreamPlayer = %CancelSound

const HUD_ALIVE_REGION = Vector2(198, 0)
const HUD_DEAD_REGION = Vector2(263, 0)
const ODOMETER_FRAME_COUNT := 9
const GUARD_DEFENSE_INCREASE := 40
var data: AllyBattlerData
var hp_frames_to_roll: int
var pp_frames_to_roll: int
var hp_odometer_speed_scale := 0
var pp: int
var psi: Array[Psi]
var state := States.NONE
var last_button_pressed_type: ActionType
var selection_index := 0
var is_guarding := false
var started_battle := false
var targeting_type: TargetType

enum States {
	NONE,
	SELECTING,
}

enum OdoMeterStates {
	TAKING_DAMAGE,
	HEALING
}
var odometer_state: OdoMeterStates

enum ActionType {
	BASH, GUARD, GOODS, PSI, TALK, RUN
}

enum TargetType {
	SINGLE_ENEMY, ALL_ENEMIES
}

func _ready() -> void:
	for button in buttons.get_children():
		if button is BaseButton:
			button.focus_exited.connect(_on_button_focus_entered)
			button.pressed.connect(_on_button_pressed)
	if data.can_talk:
		talk_button.show()
	if not data.psi.is_empty():
		psi_button.show()
	ui.hide()
	name_label.text = data.name
	bash_button.grab_focus()
	
	(hud_back_ground.texture as AtlasTexture).region.position = HUD_ALIVE_REGION
	var hp_digits := "%03d" % hp
	hp_ones_place.frame = int(hp_digits[2]) * ODOMETER_FRAME_COUNT
	hp_tens_place.frame = int(hp_digits[1]) * ODOMETER_FRAME_COUNT
	hp_hundreds_place.frame = int(hp_digits[0]) * ODOMETER_FRAME_COUNT
	
	if psi.is_empty():
		for odometer in pp_odometers:
			odometer.hide()
	
	var pp_digits := "%03d" % pp
	pp_ones_place.frame = int(pp_digits[2]) * ODOMETER_FRAME_COUNT
	pp_tens_place.frame = int(pp_digits[1]) * ODOMETER_FRAME_COUNT
	pp_hundreds_place.frame = int(pp_digits[0]) * ODOMETER_FRAME_COUNT
	
	started_battle = true

func heal(amount: int) -> void:
	if is_healing():
		await hp_ones_place.frame_changed
		hp_frames_to_roll += amount * ODOMETER_FRAME_COUNT
	elif is_taking_damage():
		await hp_ones_place.frame_changed
		hp_odometer_speed_scale = 1
		hp_frames_to_roll = amount * ODOMETER_FRAME_COUNT
	else:
		hp_frames_to_roll = amount * ODOMETER_FRAME_COUNT
		hp_odometer_speed_scale = 1
		hp_ones_place.play("default", hp_odometer_speed_scale)

func take_damage(amount: int) -> void:
	
	amount -= defense
	amount = max(amount, 1)
	damage_label.text = str(amount)
	
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(damage_label, "visible", true, 0.1)
	tween.tween_property(damage_label, "position:y", -20, 0.2)
	tween.tween_property(damage_label, "visible", false, 0.5)
	tween.tween_property(damage_label, "position:y", 0, 0.01)
	
	hurt_sound.play()
	tween = create_tween()
	tween.set_loops(1)
	tween.tween_property(self, "scale", Vector2.ONE*1.3, 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	await tween.finished
	
	if not is_alive:
		return
	
	if is_taking_damage():
		await hp_ones_place.frame_changed
		hp_frames_to_roll += amount * ODOMETER_FRAME_COUNT
	else:
		hp_frames_to_roll = amount * ODOMETER_FRAME_COUNT
		hp_odometer_speed_scale = -1
		hp_ones_place.play("default", hp_odometer_speed_scale)
		var hp_str := "%03d" % hp
		if hp_str[2] == "0":
			hp_tens_place.play("default", hp_odometer_speed_scale)
			if hp_str[1] == "0":
				hp_hundreds_place.play("default", hp_odometer_speed_scale)

func _on_hp_ones_place_frame_changed() -> void:
	
	if (not is_healing()) and (not is_taking_damage()):
		return
	
	hp_frames_to_roll -= 1
	
	if hp_ones_place.frame % ODOMETER_FRAME_COUNT == 0:
		hp -= 1
		if hp_frames_to_roll > 0:
			var hp_str := "%03d" % hp
			if hp_str[2] == "0":
				hp_tens_place.play("default", hp_odometer_speed_scale)
				if hp_str[1] == "0":
					hp_hundreds_place.play("default", hp_odometer_speed_scale)
	
	if hp == 0:
		is_alive = false
		finished_deciding_action.emit()
		if state == States.SELECTING:
			get_valid_enemy().stop_flash()
		self.size_flags_vertical = Control.SIZE_SHRINK_END
		state = States.NONE
		ui.hide()
		hp_odometer_speed_scale = 0
		hp_frames_to_roll = 0
		hp_ones_place.stop()
		hp_tens_place.stop()
		hp_hundreds_place.stop()
		(hud_back_ground.texture as AtlasTexture).region.position = HUD_DEAD_REGION
		died.emit()
		if is_talking:
			stop_talking()
			battler_i_am_talking_to.stop_talking()
		return
	
	if hp_frames_to_roll == 0:
		hp_ones_place.pause()
		hp_odometer_speed_scale = 0

func _on_hp_tens_place_frame_changed() -> void:
	if hp_tens_place.frame % ODOMETER_FRAME_COUNT == 0:
		hp_tens_place.pause()

func _on_hp_hundreds_place_frame_changed() -> void:
	if hp_hundreds_place.frame % 9 == 0:
		hp_hundreds_place.pause()

func is_healing() -> bool:
	return is_alive and hp_odometer_speed_scale > 0 and hp_frames_to_roll != 0

func is_taking_damage() -> bool:
	return is_alive and hp_odometer_speed_scale < 0 and hp_frames_to_roll != 0

func _process(delta: float) -> void:
	assert(not is_healing(), "Can't heal yet")

func decide_action() -> void:
	if is_guarding:
		is_guarding = false
		defense -= GUARD_DEFENSE_INCREASE
	ui.show()
	self.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bash_button.grab_focus()

func perform_action() -> void:
	self.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if is_talking:
		talking_logic()
		return
	
	if last_button_pressed_type == ActionType.BASH:
		var enemy := get_valid_enemy() as EnemyBattler
		pre_attack_sound.play()
		EventBus.display_text.emit("%s attacked %s" % [battler_name, enemy.battler_name])
		await EventBus.textbox_closed
		if not is_alive:
			finish_performing_action()
			return
		await enemy.take_damage(offense)
		finish_performing_action()
	elif last_button_pressed_type == ActionType.PSI:
		var psi := data.psi[0]
		pre_psi_sound.play()
		EventBus.display_text.emit("%s tried %s" % [battler_name, psi.name])
		await EventBus.textbox_closed
		if not is_alive:
			finish_performing_action()
			return
		
		# Update PP Odometer:
		pp_frames_to_roll = psi.pp_cost * ODOMETER_FRAME_COUNT
		pp_ones_place.play("default", -1)
		var pp_string := "%03d" % pp
		if pp_string[2] == "0":
			pp_tens_place.play("default", -1)
			if pp_string[1] == "0":
				pp_hundreds_place.play("default", -1)
		
		if psi.target_type == TargetType.ALL_ENEMIES:
			psi_animation.global_position = Vector2.ZERO
			psi_animation.centered = false
		elif psi.target_type == TargetType.SINGLE_ENEMY:
			psi_animation.global_position = get_valid_enemy().global_position
			if psi.frame_to_move_to_enemy != 0:
				psi_animation.global_position.x = get_viewport_rect().size.x / 2
			psi_animation.centered = true
		psi_animation.sprite_frames = psi.sprite_frames
		psi_animation.show()
		psi_animation.scale = psi.animation_scale
		psi_animation.play()
		psi_sound.stream = psi.sound
		psi_sound.play()
		await psi_animation.animation_finished
		psi_animation.hide()
		if psi.target_type == TargetType.ALL_ENEMIES:
			var targets := enemies.filter(battler_is_alive)
			for enemy in targets:
				await enemy.take_damage(psi.strength, true)
		elif psi.target_type == TargetType.SINGLE_ENEMY:
			var enemy := get_valid_enemy()
			await enemy.take_damage(psi.strength, true)
		finish_performing_action()
	elif last_button_pressed_type == ActionType.TALK:
		talk_sound.play()
		var enemy := get_valid_enemy()
		EventBus.display_text.emit("Floyd tried chatting up the %s..." % enemy.battler_name)
		await EventBus.textbox_closed
		if not is_alive:
			finish_performing_action()
			return
		if enemy.can_talk():
			EventBus.display_text.emit("It had a lot to say about %s...\nThey really hit it off!" % enemy.data.talk_topic)
			await EventBus.textbox_closed
			if not is_alive:
				finish_performing_action()
				return
			enemy.talk()
			battler_i_am_talking_to = enemy
			enemy.battler_i_am_talking_to = self
			number_of_turns_left_to_talk = randi_range(2, 3)
			self.is_talking = true
			talk_animation.show()
			talk_animation.play()
		else:
			EventBus.display_text.emit("It didn't seem interested...")
			await EventBus.textbox_closed
		finish_performing_action()
	
	elif last_button_pressed_type == ActionType.GUARD:
		EventBus.display_text.emit("%s is on guard" % battler_name)
		await EventBus.textbox_closed
		self.size_flags_vertical = Control.SIZE_SHRINK_END
		finished_performing_action.emit()

func _on_button_focus_entered() -> void:
	button_focus_sound.play()

func _on_button_pressed() -> void:
	button_pressed_sound.play()

func _on_bash_button_pressed() -> void:
	last_button_pressed_type = ActionType.BASH
	targeting_type = TargetType.SINGLE_ENEMY
	start_selecting()

func get_valid_enemy() -> EnemyBattler:
	var enemy := enemies[selection_index % enemies.size()]
	while not enemy.is_alive:
		selection_index += 1
		enemy = enemies[selection_index % enemies.size()]
	return enemy

func _input(event: InputEvent) -> void:
	if state == States.SELECTING:
		if event.is_action_pressed("ui_right") and targeting_type == TargetType.SINGLE_ENEMY:
			get_valid_enemy().stop_flash()
			selection_index += 1
			get_valid_enemy().sprite_flash()
			button_focus_sound.play()
		elif event.is_action_pressed("ui_left") and targeting_type == TargetType.SINGLE_ENEMY:
			get_valid_enemy().stop_flash()
			selection_index -= 1
			get_valid_enemy().sprite_flash()
			button_focus_sound.play()
		elif event.is_action_pressed("confirm"):
			state = States.NONE
			self.size_flags_vertical = Control.SIZE_SHRINK_END
			button_pressed_sound.play()
			if targeting_type == TargetType.ALL_ENEMIES:
				for enemy in enemies:
					enemy.stop_flash()
			elif targeting_type == TargetType.SINGLE_ENEMY:
				get_valid_enemy().stop_flash()
			ui.hide()
			finished_deciding_action.emit()
		elif event.is_action_pressed("cancel"):
			state = States.NONE
			cancel_sound.play()
			for enemy in enemies:
				enemy.stop_flash()
			ui.show()
			match last_button_pressed_type:
				ActionType.BASH:
					bash_button.grab_focus()
				ActionType.PSI:
					psi_button.grab_focus()
				ActionType.TALK:
					talk_button.grab_focus()

func _on_psi_button_pressed() -> void:
	last_button_pressed_type = ActionType.PSI
	var psi := data.psi[0]
	targeting_type = psi.target_type
	start_selecting()

func start_selecting() -> void:
	ui.hide()
	state = States.SELECTING
	if targeting_type == TargetType.SINGLE_ENEMY:
		selection_index = 0
		var enemy := get_valid_enemy()
		enemy.sprite_flash()
	elif targeting_type == TargetType.ALL_ENEMIES:
		for enemy: EnemyBattler in enemies.filter(battler_is_alive):
			enemy.sprite_flash()

func _on_talk_button_pressed() -> void:
	last_button_pressed_type = ActionType.TALK
	targeting_type = TargetType.SINGLE_ENEMY
	start_selecting()

func on_battle_won() -> void:
	talk_animation.hide()

func _on_guard_button_pressed() -> void:
	last_button_pressed_type = ActionType.GUARD
	defense += GUARD_DEFENSE_INCREASE
	self.size_flags_vertical = Control.SIZE_SHRINK_END
	ui.hide()
	finished_deciding_action.emit()
	return

func talking_logic() -> void:
	
	number_of_turns_left_to_talk -= 1
	if number_of_turns_left_to_talk == 0 or not battler_i_am_talking_to.is_alive:
		EventBus.display_text.emit("%s just finished talking" % battler_name)
		stop_talking()
		battler_i_am_talking_to.stop_talking()
	else:
		EventBus.display_text.emit("%s is busy talking" % battler_name)
	await EventBus.textbox_closed
	self.size_flags_vertical = Control.SIZE_SHRINK_END
	finished_performing_action.emit()
	return

func stop_talking() -> void:
	super.stop_talking()
	last_button_pressed_type = ActionType.BASH

func finish_performing_action() -> void:
	finished_performing_action.emit()
	self.size_flags_vertical = Control.SIZE_SHRINK_END

func _on_pp_ones_place_frame_changed() -> void:
	
	if not started_battle:
		pp_ones_place.pause()
		return
	
	pp_frames_to_roll -= 1
	
	if pp_frames_to_roll == 0:
		pp_ones_place.pause()
		return
	
	if pp_ones_place.frame % ODOMETER_FRAME_COUNT == 0:
		pp -= 1
		if pp_frames_to_roll > 0:
			var pp_string := "%03d" % pp
			if pp_string[2] == "0":
				pp_tens_place.play("default", -1)
				if pp_string[1] == "0":
					pp_hundreds_place.play("default", -1)

func _on_pp_tens_place_frame_changed() -> void:
	if pp_tens_place.frame % ODOMETER_FRAME_COUNT == 0:
		pp_tens_place.pause()

func _on_psi_animation_frame_changed() -> void:
	if psi[0].target_type == TargetType.SINGLE_ENEMY and psi_animation.frame == psi[0].frame_to_move_to_enemy:
		psi_animation.global_position.x = get_valid_enemy().global_position.x


func _on_pp_hundreds_place_frame_changed() -> void:
	if pp_hundreds_place.frame % ODOMETER_FRAME_COUNT == 0:
		pp_hundreds_place.pause()
