extends Control

signal talk_performed(category: String, sub_option: String)

@onready var main_menu = $MainMenu
@onready var sub_menu = $SubMenu
@onready var talk_button = $TalkButton
@onready var sub_menu_container = $SubMenu/VBoxContainer

var is_used_this_turn: bool = false

func _ready():
	talk_button.pressed.connect(_on_talk_button_pressed)
	main_menu.hide()
	sub_menu.hide()
	
	# カテゴリボタンの接続
	$MainMenu/VBoxContainer/TellButton.pressed.connect(func(): _show_sub_menu("TELL"))
	$MainMenu/VBoxContainer/AskButton.pressed.connect(func(): _show_sub_menu("ASK"))
	$MainMenu/VBoxContainer/ChatButton.pressed.connect(func(): _perform_talk("CHAT", ""))

func reset_turn():
	is_used_this_turn = false
	talk_button.disabled = false
	main_menu.hide()
	sub_menu.hide()

func _on_talk_button_pressed():
	if is_used_this_turn: return
	main_menu.visible = !main_menu.visible
	sub_menu.hide()

func _show_sub_menu(category: String):
	main_menu.hide()
	sub_menu.show()
	
	# 子要素をクリア
	for child in sub_menu_container.get_children():
		child.queue_free()
	
	var options = []
	if category == "TELL":
		options = [
			{"label": "グーを出す", "value": "ROCK"},
			{"label": "チョキを出す", "value": "SCISSORS"},
			{"label": "パーを出す", "value": "PAPER"}
		]
	elif category == "ASK":
		options = [
			{"label": "グーを出す？", "value": "ROCK?"},
			{"label": "チョキを出す？", "value": "SCISSORS?"},
			{"label": "パーを出す？", "value": "PAPER?"},
			{"label": "何を出す？", "value": "WHAT?"}
		]
	
	for opt in options:
		var btn = Button.new()
		btn.text = opt.label
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(func(): _perform_talk(category, opt.value))
		sub_menu_container.add_child(btn)
	
	# 戻るボタン
	var back_btn = Button.new()
	back_btn.text = "戻る"
	back_btn.modulate = Color.GRAY
	back_btn.pressed.connect(func(): 
		sub_menu.hide()
		main_menu.show()
	)
	sub_menu_container.add_child(back_btn)

func _perform_talk(category: String, sub_option: String):
	is_used_this_turn = true
	talk_button.disabled = true
	main_menu.hide()
	sub_menu.hide()
	
	talk_performed.emit(category, sub_option)
	print("Talk performed: ", category, " - ", sub_option)
	
	# 演出（仮：メッセージ表示などは今後追加）
