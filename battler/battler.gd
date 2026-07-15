@abstract
class_name Battler extends Control

signal finished_performing_action
signal died

var battler_name: String
var hp: int
var offense: int
var defense: int
var speed: int
var is_alive := true
var is_talking := false
var allies:Array[AllyBattler]
var enemies: Array[EnemyBattler]

static func create(data: BattlerData, allies: Array[AllyBattler], enemies: Array[EnemyBattler]) -> Battler:
	var battler: Battler
	if data is AllyBattlerData:
		const ALLY_BATTLER = preload("uid://qx3qpnsq13hi")
		battler = ALLY_BATTLER.instantiate()
		battler.data = data
		battler.pp = data.pp
		battler.psi = data.psi
	elif data is EnemyBattlerData:
		const ENEMY_BATTLER = preload("uid://dqrkk0wiq41jw")
		battler = ENEMY_BATTLER.instantiate()
		battler.data = data
	battler.hp = data.hp
	battler.offense = data.offense
	battler.defense = data.defense
	battler.speed = data.speed
	battler.allies = allies
	battler.enemies = enemies
	battler.battler_name = data.name
	return battler

@abstract
func perform_action() -> void

@abstract
func take_damage(amount: int) -> void
