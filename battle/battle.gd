class_name Battle extends Node2D

@onready var background: Sprite2D = %Background
@onready var allies_parent: Control = %Allies
@onready var cursor: AnimatedSprite2D = %Cursor
@onready var enemies_parent: Node2D = %Enemies
@onready var text_box: Control = %TextBox
@onready var text_label: Label = %TextLabel
@onready var text_box_timer: Timer = %TextBoxTimer
@onready var music: AudioStreamPlayer = %Music
@onready var battle_won_sound: AudioStreamPlayer = %BattleWonSound
@onready var labels: HBoxContainer = %Labels

static var data: BattleData

var allies: Array[AllyBattler]
var enemies: Array[EnemyBattler]
var number_of_living_allies: int
var number_of_living_enemies: int

func _ready() -> void:
	randomize()
	EventBus.display_text.connect(_on_display_text)
	background.texture = data.battle_background
	music.stream = data.battle_music
	music.play()
	if data.background_shader:
		background.material = data.background_shader
	
	for i in (data.allies_data.size()):
		number_of_living_allies += 1
		var ally := Battler.create(data.allies_data[i], allies, enemies) as AllyBattler
		ally.move_cursor_to.connect(_on_move_cursor_to)
		ally.hide_cursor.connect(func(): cursor.hide())
		ally.died.connect(func(): number_of_living_allies -= 1)
		allies_parent.add_child(ally)
		allies.append(ally)
	
	var screen_size := get_viewport_rect().size
	var smaller_screen_width = screen_size.x / 2
	var step = smaller_screen_width / (data.enemies_data.size()-1)
	for i in range(data.enemies_data.size()):
		number_of_living_enemies += 1
		var enemy := Battler.create(data.enemies_data[i], allies, enemies)
		enemy.died.connect(func(): number_of_living_enemies -= 1)
		enemies.append(enemy)
		enemies_parent.add_child(enemy)
		if data.enemies_data.size() == 1:
			enemy.global_position = screen_size / 2
		else:
			enemy.global_position = Vector2(step*i+smaller_screen_width/2, screen_size.y/2)
	
	while not is_battle_finished():
		for ally in allies:
			if not ally.is_alive or ally.is_talking:
				continue
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
			if is_battle_finished():
				finish_battle()
				return

func sort_by_highest_speed(b1: Battler, b2: Battler) -> bool:
	if b1.speed > b2.speed:
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
	
	if Input.is_action_just_pressed("exit"):
		get_tree().change_scene_to_file("res://title_screen/title_screen.tscn")
	
	#for i in range(3):
		#var ally := allies[i]
		#var label: Label = labels.get_children()[i]
		#var text := "HP=%d\n" % ally.hp
		#text += "frames_to_roll=%d\n" % ally.frames_to_roll
		#text += "hp_odometer_speed_scale=%d\n" % ally.hp_odometer_speed_scale
		#text += "is_taking_damage=%s\n" % ally.is_taking_damage()
		#label.text = text
	
	#var floyd := allies[1]
	#%Label1.text = "is_talking=%s\nturns_to_talk=%d" % [floyd.is_talking, floyd.number_of_turns_left_to_talk]
	#%Label2.text = "is_talking=%s\n" % enemies[0].is_talking

func _on_text_box_timer_timeout() -> void:
	if text_label.visible_ratio == 1.0:
		return
	text_label.visible_characters += 1
	text_box_timer.start()

func _on_damage_button_pressed() -> void:
	allies[0].take_damage(20)

func _on_heal_button_pressed() -> void:
	allies[0].heal(20)

func is_battle_finished() -> bool:
	return enemies_won() or allies_won()

func enemies_won() -> bool:
	return number_of_living_allies == 0

func allies_won() -> bool:
	return number_of_living_enemies == 0

func finish_battle() -> void:
	music.stop()
	if allies_won():
		for ally in allies:
			ally.on_battle_won()
		battle_won_sound.play()
		EventBus.display_text.emit("You Won!")
		await EventBus.textbox_closed
		EventBus.display_text.emit("Travis and friends got 142 XP")
		await EventBus.textbox_closed
		get_tree().change_scene_to_file("res://title_screen/title_screen.tscn")
	else:
		EventBus.display_text.emit("You Lost...")
		await EventBus.textbox_closed
		get_tree().change_scene_to_file("res://title_screen/title_screen.tscn")
