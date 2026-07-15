class_name EnemyBattlerData extends BattlerData

@export var sprite: Texture
@export_range(0.0, 1.0, 0.1) var chance_to_waste_turn := 0.50
@export_multiline() var waste_turn_text := "Enemy Did Nothing"
@export var talk_topic: String = "Food"
@export var can_be_talked_to := true
@export var talk_bubble_height := 40
@export_multiline() var death_text := "The Enemy disappeared into thin air"
