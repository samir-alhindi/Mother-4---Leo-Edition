class_name Battle extends Node2D

@onready var background: Sprite2D = %Background
@onready var ally_data_ui: HBoxContainer = %AllyDataUIs

@export var data: BattleData

static func create(data: BattleData) -> Battle:
	const BATTLE = preload("uid://ba7fj5bmq4wfb")
	var battle: Battle = BATTLE.instantiate()
	battle.data = data
	return battle

func _ready() -> void:
	background.texture = data.battle_background
	for ally_data in data.allies_data:
		var ally := AllyBattler.create(ally_data)
		ally_data_ui.add_child(ally)
