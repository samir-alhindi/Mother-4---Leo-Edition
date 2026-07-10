class_name AllyBattler extends Battler

@onready var bash_button: TextureButton = %BashButton
@onready var name_label: Label = %NameLabel
@onready var ui: CanvasLayer = %Ui

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

static func create(data: AllyBattlerData) -> AllyBattler:
	const ALLY_BATTLER = preload("uid://qx3qpnsq13hi")
	var ally: AllyBattler = ALLY_BATTLER.instantiate()
	ally.data = data
	ally.hp = data.hp
	return ally

func _ready() -> void:
	ui.show()
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
