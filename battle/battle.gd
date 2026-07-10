class_name Battle extends Node2D

@onready var background: Sprite2D = %Background
@onready var ally_data_ui: HBoxContainer = %AllyDataUIs
@onready var enemies_node: Node2D = %Enemies
@onready var cursor: AnimatedSprite2D = %Cursor

@export var data: BattleData

var allies: Array[AllyBattler]
var enemies: Array[EnemyBattler]

static func create(data: BattleData) -> Battle:
	const BATTLE = preload("uid://ba7fj5bmq4wfb")
	var battle: Battle = BATTLE.instantiate()
	battle.data = data
	return battle

func _ready() -> void:
	background.texture = data.battle_background
	for ally_data in data.allies_data:
		var ally := Battler.create(ally_data, allies, enemies)
		(ally as AllyBattler).move_cursor_to.connect(_on_move_cursor_to)
		ally_data_ui.add_child(ally)
		allies.append(ally)
	for enemy_data in data.enemies_data:
		var enemy := Battler.create(enemy_data, allies, enemies)
		enemies.append(enemy)
		enemies_node.add_child(enemy)
		enemy.global_position = Vector2(320/2,180/2)
	
	while true:
		for ally in allies:
			ally.decide_action()
			await ally.finished_deciding_action
		
		var battlers: Array[Battler] = allies + enemies
		battlers.sort_custom(sort_by_highest_speed)
		
		for battler in battlers:
			if not battler.is_alive:
				continue
			battler.perform_action()
			await battler.finished_performing_action

func sort_by_highest_speed(b1: Battler, b2: Battler) -> bool:
	if b1.speed < b2.speed:
		return true
	return false

func _on_move_cursor_to(pos: Vector2) -> void:
	cursor.show()
	pos.x -= 20
	cursor.global_position = pos
