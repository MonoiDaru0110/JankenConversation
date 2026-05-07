extends Control

@export var hand_type: HandData.Hand = HandData.Hand.ROCK
@export var attack_power: int = 4
@export var defense_power: int = 3

@onready var attack_label = $MarginContainer/VBoxContainer/Stats/AttackLabel
@onready var defense_label = $MarginContainer/VBoxContainer/Stats/DefenseLabel
@onready var hand_name_label = $MarginContainer/VBoxContainer/HandNameLabel
@onready var hand_icon = $MarginContainer/VBoxContainer/HandIcon

signal hovered
signal unhovered

var is_hovered: bool = false
var default_position: Vector2

func _ready():
	update_ui()
	# マウスイベントの接続
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# 基準となるピボットを中心（真ん中）に設定
	pivot_offset = size / 2

func _on_mouse_entered():
	is_hovered = true
	z_index = 10
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15)
	hovered.emit()

func _on_mouse_exited():
	is_hovered = false
	z_index = 0
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	unhovered.emit()

func update_ui():
	# 変数の値をUIに反映
	attack_label.text = str(attack_power)
	defense_label.text = str(defense_power)
	
	match hand_type:
		HandData.Hand.ROCK:
			hand_name_label.text = "グー"
			# アイコンの色をラフ画像に合わせて調整（仮）
			hand_icon.modulate = Color(0.3, 0.6, 1.0) # 青系
		HandData.Hand.PAPER:
			hand_name_label.text = "パー"
			hand_icon.modulate = Color(0.3, 1.0, 0.4) # 緑系
		HandData.Hand.SCISSORS:
			hand_name_label.text = "チョキ"
			hand_icon.modulate = Color(1.0, 0.3, 0.3) # 赤系

func set_hand_data(data: HandData):
	hand_type = data.hand_type
	attack_power = data.attack_power
	defense_power = data.defense_power
	if is_inside_tree():
		update_ui()
