extends Control

# 手の情報
var hand_data: HandData

@onready var background = $Background
@onready var hand_icon = $HandIcon
@onready var stats_container = $Stats
@onready var atk_icon = $Stats/AtkIcon
@onready var def_icon = $Stats/DefIcon
@onready var attack_label = $Stats/AtkIcon/AttackLabel
@onready var defense_label = $Stats/DefIcon/DefenseLabel

# ユーザー提供のテクスチャのロード
var tex_front = load("res://assets/cards/カードデザイン表ラフ.png")
var tex_back = load("res://assets/cards/カードデザイン裏ラフ.png")
var tex_atk_icon = load("res://assets/cards/カード攻撃力.png")
var tex_def_icon = load("res://assets/cards/カード防御力.png")
var icon_rock = load("res://assets/cards/グー素材.png")
var icon_paper = load("res://assets/cards/パー素材.png")
var icon_scissors = load("res://assets/cards/チョキ素材.png")

signal hovered
signal unhovered
signal clicked(card)

var is_hovered: bool = false
var is_selected: bool = false
var is_front: bool = true

func _ready():
	# 初期化
	pivot_offset = Vector2(110, 165)
	
	if tex_front: background.texture = tex_front
	if tex_atk_icon: atk_icon.texture = tex_atk_icon
	if tex_def_icon: def_icon.texture = tex_def_icon
	
	# マウスイベントの接続
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	# 既にデータがあれば反映
	if hand_data:
		set_hand_data(hand_data)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

func _on_mouse_entered():
	if is_selected or not is_front: return
	is_hovered = true
	z_index = 10
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15)
	hovered.emit()

func _on_mouse_exited():
	if is_selected or not is_front: return
	is_hovered = false
	z_index = 0
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	unhovered.emit()

# 表面・裏面の切り替え
func set_facing(front: bool):
	is_front = front
	if is_front:
		background.texture = tex_front
		hand_icon.visible = true
		stats_container.visible = true
	else:
		background.texture = tex_back
		hand_icon.visible = false
		stats_container.visible = false

# ひっくり返るアニメーション（強化版：迫りくる叩きつけ演出）
func flip_to_front():
	var original_scale_y = scale.y # 現在の基本スケール（1.2想定）
	var peak_scale = original_scale_y * 1.8 # ぐわっと迫るサイズ（約2.16）
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# 1. 裏返りつつ手前に迫る（巨大化）
	tween.set_parallel(true)
	tween.tween_property(self, "scale:x", 0.0, 0.2)
	tween.tween_property(self, "scale:y", peak_scale, 0.2)
	
	# 2. 表面に切り替えて、巨大なまま広げる
	tween.set_parallel(false)
	tween.tween_callback(set_facing.bind(true))
	tween.set_parallel(true)
	tween.tween_property(self, "scale:x", peak_scale, 0.2)
	
	# 3. 最大サイズで一瞬「溜め」
	tween.set_parallel(false)
	tween.tween_interval(0.15)
	
	# 4. 素早く叩きつける（元のサイズへ）
	tween.tween_property(self, "scale", Vector2(original_scale_y, original_scale_y), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

func set_hand_data(data: HandData):
	hand_data = data
	if not is_inside_tree() or not background: return
	
	attack_label.text = str(data.attack_power)
	defense_label.text = str(data.defense_power)
	
	match data.hand_type:
		HandData.Hand.ROCK:
			hand_icon.texture = icon_rock
		HandData.Hand.PAPER:
			hand_icon.texture = icon_paper
		HandData.Hand.SCISSORS:
			hand_icon.texture = icon_scissors
	
	set_facing(is_front)
