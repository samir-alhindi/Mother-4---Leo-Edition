class_name AllyBattler extends Battler

signal finished_deciding_action
signal move_cursor_to(pos: Vector2)

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

const HUD_ALIVE_REGION = Vector2(198, 0)
const HUD_DEAD_REGION = Vector2(263, 0)
const ODOMETER_FRAME_COUNT := 9
var data: AllyBattlerData
var frames_to_roll: int
var hp_odometer_speed_scale := 1
var pp: int
var psi: Array
var state := States.NONE
var selection_index := 0

enum States {
	NONE,
	SELECTING,
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
	frames_to_roll = amount * ODOMETER_FRAME_COUNT
	hp_odometer_speed_scale = -1
	hp_ones_place.play("default", hp_odometer_speed_scale)

func _on_hp_ones_place_frame_changed() -> void:
	
	if hp_ones_place.frame % ODOMETER_FRAME_COUNT == 0:
		hp += 1 if is_healing() else -1
	
	if hp == 0:
		hp_ones_place.stop()
		hp_tens_place.stop()
		hp_hundreds_place.stop()
		(hud_back_ground.texture as AtlasTexture).region.position = HUD_DEAD_REGION
		return
	
	if is_taking_damage():
		if hp_ones_place.frame == 9 * ODOMETER_FRAME_COUNT:
			hp_tens_place.play("default", hp_odometer_speed_scale)
	else:
		if hp_ones_place.frame == 0:
			hp_tens_place.play("default", hp_odometer_speed_scale)
	
	frames_to_roll -= 1
	if frames_to_roll == 0:
		hp_ones_place.pause()

func _on_hp_tens_place_frame_changed() -> void:
	if hp_tens_place.frame % ODOMETER_FRAME_COUNT == 0:
		hp_tens_place.pause()
		if is_taking_damage():
			if hp_tens_place.frame == ODOMETER_FRAME_COUNT * 9:
				hp_hundreds_place.play("default", hp_odometer_speed_scale)
		else:
			if hp_tens_place.frame == 0:
				hp_hundreds_place.play("default", hp_odometer_speed_scale)

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
	self.size_flags_vertical = VERTICAL_ALIGNMENT_TOP
	bash_button.grab_focus()

func perform_action() -> void:
	pass

func _on_button_focus_entered() -> void:
	button_focus_sound.play()

func _on_button_pressed() -> void:
	button_pressed_sound.play()

func _on_bash_button_pressed() -> void:
	buttons.hide()
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
