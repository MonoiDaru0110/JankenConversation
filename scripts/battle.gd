extends Control

# 戦闘情報の管理
@export var enemy_name: String = "大魔王 ジャキドウ"
@export var enemy_max_hp: int = 500
var enemy_current_hp: int

@export var player_max_hp: int = 100
var player_current_hp: int

# 手の情報を管理 (HandData Resourceを使用)
@export var enemy_hands: Array[HandData] = []
@export var player_hands: Array[HandData] = []

@onready var enemy_name_label = $EnemyUI/EnemyNameLabel
@onready var enemy_hp_bar = $EnemyUI/EnemyHPBar
@onready var player_hp_bar = $PlayerUI/PlayerHPBar
@onready var hand_container = $PlayerUI/HandContainer

const CARD_SCENE = preload("res://scenes/card.tscn")

func _ready():
	setup_battle()

func setup_battle():
	enemy_current_hp = enemy_max_hp
	player_current_hp = player_max_hp
	
	enemy_name_label.text = enemy_name
	update_hp_ui()
	
	# テスト用に手札が空ならデフォルトを作成
	if player_hands.is_empty():
		for i in range(3):
			var data = HandData.new()
			data.hand_type = i as HandData.Hand
			data.attack_power = 10 + i
			data.defense_power = 5 + i
			player_hands.append(data)
	
	# 手札（プレイヤー）の表示
	for hand_data in player_hands:
		var card_instance = CARD_SCENE.instantiate()
		hand_container.add_child(card_instance)
		if card_instance.has_method("set_hand_data"):
			card_instance.set_hand_data(hand_data)
		
		# シグナルの接続
		card_instance.hovered.connect(func(): arrange_cards(card_instance))
		card_instance.unhovered.connect(func(): arrange_cards(null))
	
	# 少し待ってから扇形に配置
	await get_tree().process_frame
	arrange_cards()

func arrange_cards(hovered_card: Control = null):
	var cards = hand_container.get_children()
	var card_count = cards.size()
	if card_count == 0: return
	
	var angle_step = 8.0
	var total_angle = angle_step * (card_count - 1)
	var start_angle = -total_angle / 2.0
	
	var radius = 1000.0
	var base_pos = Vector2(hand_container.size.x / 2, hand_container.size.y)
	
	for i in range(card_count):
		var card = cards[i]
		var angle_deg = start_angle + i * angle_step
		
		# ホバー中のカードがある場合、左右のカードを押し出す
		if hovered_card != null:
			var hovered_idx = cards.find(hovered_card)
			if i < hovered_idx:
				angle_deg -= 1.5 # 左に寄せる
			elif i > hovered_idx:
				angle_deg += 1.5 # 右に寄せる
			elif i == hovered_idx:
				# ホバー中のカード自体は少し上に上げる
				pass 
		
		var angle_rad = deg_to_rad(angle_deg)
		var x = sin(angle_rad) * radius
		var y = -cos(angle_rad) * radius + radius
		
		# ターゲット位置の計算
		var target_pos = base_pos + Vector2(x, y) - Vector2(card.size.x / 2, card.size.y)
		
		# Tweenで滑らかに移動
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position", target_pos, 0.15)
		tween.tween_property(card, "rotation", angle_rad, 0.15)

func update_hp_ui():
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_current_hp
	
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_current_hp
