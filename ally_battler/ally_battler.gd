class_name AllyBattler extends Battler

@onready var bash_button: TextureButton = %BashButton
@onready var name_label: Label = %NameLabel
@onready var ui: CanvasLayer = %Ui

var data: AllyBattlerData

static func create(data: AllyBattlerData) -> AllyBattler:
	const ALLY_BATTLER = preload("uid://qx3qpnsq13hi")
	var ally: AllyBattler = ALLY_BATTLER.instantiate()
	ally.data = data
	return ally

func _ready() -> void:
	ui.show()
	name_label.text = data.name
	bash_button.grab_focus()
