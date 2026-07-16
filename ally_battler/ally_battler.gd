class_name AllyBattler extends Battler

signal finished_deciding_action
signal move_cursor_to(pos: Vector2)
signal hide_cursor

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

const HUD_ALIVE_REGION = Vector2(198, 0)
const HUD_DEAD_REGION = Vector2(263, 0)
const ODOMETER_FRAME_COUNT := 9
const GUARD_DEFENSE_INCREASE := 40
var data: AllyBattlerData
var frames_to_roll: int
var hp_odometer_speed_scale := 0
var pp: int
var psi: Array
var state := States.NONE
var action_type: ActionType
var selection_index := 0
var target_battler: Battler
var target_battlers: Array[EnemyBattler]
var is_guarding := false

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

func heal(amount: int) -> void:
	if is_healing():
		await hp_ones_place.frame_changed
		frames_to_roll += amount * ODOMETER_FRAME_COUNT
	elif is_taking_damage():
		await hp_ones_place.frame_changed
		hp_odometer_speed_scale = 1
		frames_to_roll = amount * ODOMETER_FRAME_COUNT
	else:
		frames_to_roll = amount * ODOMETER_FRAME_COUNT
		hp_odometer_speed_scale = 1
		hp_ones_place.play("default", hp_odometer_speed_scale)

func take_damage(amount: int) -> void:
	hurt_sound.play()
	var tween := create_tween()
	tween.set_loops(1)
	tween.tween_property(self, "scale", Vector2.ONE*1.3, 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	await tween.finished
	
	if not is_alive:
		return
	
	if is_taking_damage():
		await hp_ones_place.frame_changed
		frames_to_roll += amount * ODOMETER_FRAME_COUNT
	else:
		frames_to_roll = amount * ODOMETER_FRAME_COUNT
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
	
	frames_to_roll -= 1
	
	if hp_ones_place.frame % ODOMETER_FRAME_COUNT == 0:
		hp -= 1
		if frames_to_roll > 0:
			var hp_str := "%03d" % hp
			if hp_str[2] == "0":
				hp_tens_place.play("default", hp_odometer_speed_scale)
				if hp_str[1] == "0":
					hp_hundreds_place.play("default", hp_odometer_speed_scale)
	
	if hp == 0:
		is_alive = false
		finished_deciding_action.emit()
		if state == States.SELECTING:
			hide_cursor.emit()
			get_valid_enemy().stop_flash()
		self.size_flags_vertical = Control.SIZE_SHRINK_END
		state = States.NONE
		ui.hide()
		hp_odometer_speed_scale = 0
		frames_to_roll = 0
		hp_ones_place.stop()
		hp_tens_place.stop()
		hp_hundreds_place.stop()
		(hud_back_ground.texture as AtlasTexture).region.position = HUD_DEAD_REGION
		died.emit()
		if is_talking:
			stop_talking()
			battler_i_am_talking_to.stop_talking()
		return
	
	if frames_to_roll == 0:
		hp_ones_place.pause()
		hp_odometer_speed_scale = 0

func _on_hp_tens_place_frame_changed() -> void:
	if hp_tens_place.frame % ODOMETER_FRAME_COUNT == 0:
		hp_tens_place.pause()

func _on_hp_hundreds_place_frame_changed() -> void:
	if hp_hundreds_place.frame % 9 == 0:
		hp_hundreds_place.pause()

func is_healing() -> bool:
	return is_alive and hp_odometer_speed_scale > 0 and frames_to_roll != 0

func is_taking_damage() -> bool:
	return is_alive and hp_odometer_speed_scale < 0 and frames_to_roll != 0

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
	
	if action_type == ActionType.BASH:
		var enemy := get_valid_enemy() as EnemyBattler
		pre_attack_sound.play()
		EventBus.display_text.emit("%s attacked %s" % [battler_name, enemy.battler_name])
		await EventBus.textbox_closed
		await enemy.take_damage(offense)
		self.size_flags_vertical = Control.SIZE_SHRINK_END
		finished_performing_action.emit()
	elif action_type == ActionType.PSI:
		var psi := data.psi[0]
		pre_psi_sound.play()
		EventBus.display_text.emit("%s tried %s" % [battler_name, psi.name])
		await EventBus.textbox_closed
		if psi.target_all_enemies:
			psi_animation.global_position = Vector2.ZERO
			psi_animation.centered = false
		else:
			psi_animation.global_position = get_valid_enemy().global_position
			psi_animation.centered = true
		psi_animation.sprite_frames = psi.sprite_frames
		psi_animation.show()
		psi_animation.scale = psi.animation_scale
		psi_animation.play()
		psi_sound.stream = psi.sound
		psi_sound.play()
		await psi_animation.animation_finished
		psi_animation.hide()
		if psi.target_all_enemies:
			var targets := enemies.filter(battler_is_alive)
			for enemy in targets:
				await enemy.take_damage(psi.strength, true)
		else:
			var enemy := get_valid_enemy()
			await enemy.take_damage(psi.strength)
		self.size_flags_vertical = Control.SIZE_SHRINK_END
		finished_performing_action.emit()
	elif action_type == ActionType.TALK:
		talk_sound.play()
		var enemy := get_valid_enemy()
		EventBus.display_text.emit("Floyd tried chatting up the %s..." % enemy.battler_name)
		await EventBus.textbox_closed
		if enemy.can_talk():
			EventBus.display_text.emit("It had a lot to say about %s...\nThey really hit it off!" % enemy.data.talk_topic)
			await EventBus.textbox_closed
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
		self.size_flags_vertical = Control.SIZE_SHRINK_END
		finished_performing_action.emit()
	
	elif action_type == ActionType.GUARD:
		EventBus.display_text.emit("%s is on guard" % battler_name)
		await EventBus.textbox_closed
		self.size_flags_vertical = Control.SIZE_SHRINK_END
		finished_performing_action.emit()

func _on_button_focus_entered() -> void:
	button_focus_sound.play()

func _on_button_pressed() -> void:
	button_pressed_sound.play()

func _on_bash_button_pressed() -> void:
	action_type = ActionType.BASH
	start_selecting()

func get_valid_enemy() -> EnemyBattler:
	var enemy := enemies[selection_index % enemies.size()]
	while not enemy.is_alive:
		selection_index += 1
		enemy = enemies[selection_index % enemies.size()]
	return enemy

func _input(event: InputEvent) -> void:
	if state == States.SELECTING:
		if event.is_action_pressed("ui_right"):
			get_valid_enemy().stop_flash()
			selection_index += 1
			get_valid_enemy().sprite_flash()
			move_cursor_to.emit(get_valid_enemy().global_position)
			button_focus_sound.play()
		elif event.is_action_pressed("ui_left"):
			get_valid_enemy().stop_flash()
			selection_index -= 1
			get_valid_enemy().sprite_flash()
			move_cursor_to.emit(get_valid_enemy().global_position)
			button_focus_sound.play()
		elif event.is_action_pressed("ui_accept"):
			hide_cursor.emit()
			state = States.NONE
			self.size_flags_vertical = Control.SIZE_SHRINK_END
			button_pressed_sound.play()
			var enemy := get_valid_enemy()
			enemy.stop_flash()
			target_battler = enemy
			ui.hide()
			finished_deciding_action.emit()

func _on_psi_button_pressed() -> void:
	action_type = ActionType.PSI
	var psi := data.psi[0]
	if psi.target_all_enemies:
		self.size_flags_vertical = Control.SIZE_SHRINK_END
		ui.hide()
		finished_deciding_action.emit()
		return
	start_selecting()

func start_selecting() -> void:
	ui.hide()
	state = States.SELECTING
	selection_index = 0
	var enemy := get_valid_enemy()
	enemy.sprite_flash()
	move_cursor_to.emit(enemy.global_position)

func _on_talk_button_pressed() -> void:
	action_type = ActionType.TALK
	start_selecting()

func on_battle_won() -> void:
	talk_animation.hide()

func _on_guard_button_pressed() -> void:
	action_type = ActionType.GUARD
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
	action_type = ActionType.BASH
