extends AnimatedSprite2D

var current_value: int
var target_value: int

func increase(amount: int) -> void:
	update(current_value+amount)

func decrease(amount: int) -> void:
	update(current_value-amount)

func update(new_value: int) -> void:
	pass
