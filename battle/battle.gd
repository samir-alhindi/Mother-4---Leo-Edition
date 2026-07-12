class_name Battle extends Node2D

@onready var background: Sprite2D = %Background
@onready var allies_parent: Control = %Allies
@onready var cursor: AnimatedSprite2D = %Cursor
@onready var enemies_parent: Node2D = %Enemies
@onready var text_box: Control = %TextBox
@onready var text_label: Label = %TextLabel
@onready var text_box_timer: Timer = %TextBoxTimer

@export var data: BattleData

var allies: Array[AllyBattler]
var enemies: Array[EnemyBattler]

static func create(data: BattleData) -> Battle:
	const BATTLE = preload("uid://ba7fj5bmq4wfb")
	var battle: Battle = BATTLE.instantiate()
	battle.data = data
	return battle

func _ready() -> void:
	EventBus.display_text.connect(_on_display_text)
	background.texture = data.battle_background
	
	for i in (data.allies_data.size()):
		var ally := Battler.create(data.allies_data[i], allies, enemies) as AllyBattler
		ally.move_cursor_to.connect(_on_move_cursor_to)
		ally.hide_cursor.connect(func(): cursor.hide())
		allies_parent.add_child(ally)
		allies.append(ally)
	
	var screen_size := get_viewport_rect().size
	var smaller_screen_width = screen_size.x / 2
	var step = smaller_screen_width / (data.enemies_data.size()-1)
	for i in range(data.enemies_data.size()):
		var enemy := Battler.create(data.enemies_data[i], allies, enemies)
		enemies.append(enemy)
		enemies_parent.add_child(enemy)
		enemy.global_position = Vector2(step*i+smaller_screen_width/2, screen_size.y/2)
	
	while true:
		for ally in allies:
			ally.decide_action()
			await ally.finished_deciding_action
			await get_tree().create_timer(0.1).timeout
		
		var battlers: Array[Battler]
		for ally in allies:
			battlers.append(ally)
		for enemy in enemies:
			battlers.append(enemy)
		battlers.sort_custom(sort_by_highest_speed)
		
		for battler in battlers:
			if not battler.is_alive:
				continue
			battler.perform_action()
			await battler.finished_performing_action
			await get_tree().create_timer(0.1).timeout

func sort_by_highest_speed(b1: Battler, b2: Battler) -> bool:
	if b1.speed < b2.speed:
		return true
	return false

func _on_move_cursor_to(pos: Vector2) -> void:
	cursor.show()
	pos.x -= 20
	cursor.global_position = pos

func _on_display_text(text: String) -> void:
	text_box.show()
	text_label.text = text
	text_label.visible_characters = 0
	text_box_timer.start()

func _process(delta: float) -> void:
	if text_box.visible and Input.is_action_just_pressed("ui_accept"):
		text_box.hide()
		EventBus.textbox_closed.emit()

func _on_text_box_timer_timeout() -> void:
	if text_label.visible_ratio == 1.0:
		return
	text_label.visible_characters += 1
	text_box_timer.start()
