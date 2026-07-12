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

const HUD_ALIVE_REGION = Vector2(198, 0)
const HUD_DEAD_REGION = Vector2(263, 0)
const ODOMETER_FRAME_COUNT := 9
var data: AllyBattlerData
var frames_to_roll: int
var hp_odometer_speed_scale := 1
var pp: int
var psi: Array
var state := States.NONE
var action_type: ActionType
var selection_index := 0
var target_battler: Battler
var target_battlers: Array[Battler]

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
	frames_to_roll = amount * ODOMETER_FRAME_COUNT
	hp_odometer_speed_scale = 1
	hp_ones_place.play("default", hp_odometer_speed_scale)

func take_damage(amount: int) -> void:
	hurt_sound.play()
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(self, "modulate:a", 0, 0.1)
	tween.tween_property(self, "modulate:a", 1, 0.1)
	await tween.finished
	
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
	
	if hp_ones_place.frame % ODOMETER_FRAME_COUNT == 0:
		hp += 1 if is_healing() else -1
		var hp_str := "%03d" % hp
		if hp_str[2] == "0":
			hp_tens_place.play("default", hp_odometer_speed_scale)
			if hp_str[1] == "0":
				hp_hundreds_place.play("default", hp_odometer_speed_scale)
	
	if hp == 0:
		hp_ones_place.stop()
		hp_tens_place.stop()
		hp_hundreds_place.stop()
		(hud_back_ground.texture as AtlasTexture).region.position = HUD_DEAD_REGION
		return
	
	#if is_taking_damage():
		#if hp_ones_place.frame == 9 * ODOMETER_FRAME_COUNT:
			#hp_tens_place.play("default", hp_odometer_speed_scale)
	#else:
		#if hp_ones_place.frame == 0:
			#hp_tens_place.play("default", hp_odometer_speed_scale)
	
	frames_to_roll -= 1
	if frames_to_roll == 0:
		hp_ones_place.pause()

func _on_hp_tens_place_frame_changed() -> void:
	if hp_tens_place.frame % ODOMETER_FRAME_COUNT == 0:
		hp_tens_place.pause()
		#if is_taking_damage():
			#if hp_tens_place.frame == ODOMETER_FRAME_COUNT * 9:
				#hp_hundreds_place.play("default", hp_odometer_speed_scale)
		#else:
			#if hp_tens_place.frame == 0:
				#hp_hundreds_place.play("default", hp_odometer_speed_scale)

func _on_hp_hundreds_place_frame_changed() -> void:
	if hp_hundreds_place.frame % 9 == 0:
		hp_hundreds_place.pause()

func is_healing() -> bool:
	return hp_odometer_speed_scale > 0 and frames_to_roll != 0

func is_taking_damage() -> bool:
	return hp_odometer_speed_scale < 0 and frames_to_roll != 0

func _process(delta: float) -> void:
	%HpLabel.text = "HP=%d" % hp

func decide_action() -> void:
	ui.show()
	self.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bash_button.grab_focus()

func perform_action() -> void:
	self.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if action_type == ActionType.BASH:
		pre_attack_sound.play()
		EventBus.display_text.emit("%s attacked %s" % [battler_name, target_battler.battler_name])
		await EventBus.textbox_closed
		hit_sound.play()
		await target_battler.take_damage(offense)
		self.size_flags_vertical = Control.SIZE_SHRINK_END
		finished_performing_action.emit()

func _on_button_focus_entered() -> void:
	button_focus_sound.play()

func _on_button_pressed() -> void:
	button_pressed_sound.play()

func _on_bash_button_pressed() -> void:
	ui.hide()
	state = States.SELECTING
	selection_index = 0
	var enemy := get_valid_enemy()
	enemy.sprite_flash()
	move_cursor_to.emit(enemy.global_position)

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
			action_type = ActionType.BASH
			hide_cursor.emit()
			state = States.NONE
			self.size_flags_vertical = Control.SIZE_SHRINK_END
			button_pressed_sound.play()
			var enemy := get_valid_enemy()
			enemy.stop_flash()
			target_battler = enemy
			ui.hide()
			finished_deciding_action.emit()
