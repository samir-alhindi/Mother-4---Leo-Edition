extends CanvasLayer

@onready var buttons: VBoxContainer = %Buttons
@onready var cursor_sound: AudioStreamPlayer = %CursorSound
@export var battles: Array[BattleData]

func _ready() -> void:
	for data in battles:
		var button := Button.new()
		buttons.add_child(button)
		button.text = data.name
		button.focus_entered.connect(
			func():
				cursor_sound.play()
		)
		button.pressed.connect(
			func():
				Battle.data = data
				get_tree().change_scene_to_file("res://battle/battle.tscn")
				
		)
	buttons.get_children()[0].grab_focus()
	
