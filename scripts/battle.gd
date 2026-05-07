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
@onready var enemy_hand_container = $EnemyHandContainer

# 移動後のパス
@onready var player_hp_bar = $DuelUI/PlayerHPBar
@onready var player_hp_label = $DuelUI/PlayerHPBar/PlayerHPLabel
@onready var hand_container = $PlayerUI/HandContainer
@onready var confirm_button = $DuelUI/ConfirmButton

@onready var dimmer = $Dimmer
@onready var enemy_duel_pos = $DuelUI/EnemyDuelPos
@onready var player_duel_pos = $DuelUI/PlayerDuelPos

var selected_card: Control = null
var is_janken_phase: bool = false

const CARD_SCENE = preload("res://scenes/card.tscn")

func _ready():
	setup_battle()
	if dimmer: dimmer.gui_input.connect(_on_dimmer_gui_input)
	if confirm_button: confirm_button.pressed.connect(_on_confirm_button_pressed)

func setup_battle():
	enemy_current_hp = enemy_max_hp
	player_current_hp = player_max_hp
	
	enemy_name_label.text = enemy_name
	
	# 敵の手札の初期化（空の場合）
	if enemy_hands.is_empty():
		for i in range(3):
			var data = HandData.new()
			data.hand_type = i as HandData.Hand
			data.attack_power = 8 + i
			data.defense_power = 3 + i
			enemy_hands.append(data)
	
	# 敵の手札の表示
	for child in enemy_hand_container.get_children(): child.queue_free()
	for hand_data in enemy_hands:
		var card_instance = CARD_SCENE.instantiate()
		enemy_hand_container.add_child(card_instance)
		if card_instance.has_method("set_hand_data"):
			card_instance.set_hand_data(hand_data)
		card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# プレイヤーの手札の初期化（空の場合）
	if player_hands.is_empty():
		for i in range(3):
			var data = HandData.new()
			data.hand_type = i as HandData.Hand
			data.attack_power = 10 + i
			data.defense_power = 5 + i
			player_hands.append(data)
	
	# プレイヤーの手札の表示
	for child in hand_container.get_children(): child.queue_free()
	for hand_data in player_hands:
		var card_instance = CARD_SCENE.instantiate()
		hand_container.add_child(card_instance)
		if card_instance.has_method("set_hand_data"):
			card_instance.set_hand_data(hand_data)
		
		card_instance.hovered.connect(func(): if selected_card == null: arrange_cards(card_instance))
		card_instance.unhovered.connect(func(): if selected_card == null: arrange_cards(null))
		card_instance.clicked.connect(_on_card_clicked)
	
	update_hp_ui()
	await get_tree().process_frame
	arrange_cards()

func _on_card_clicked(card):
	if is_janken_phase: return
	
	if selected_card == card:
		deselect_card()
		return
		
	if selected_card != null:
		deselect_card()
		
	selected_card = card
	selected_card.is_selected = true
	arrange_cards()
	
	# 選択されたカードを中央に移動して拡大
	selected_card.z_index = 100
	selected_card.pivot_offset = Vector2(110, 165)
	
	var center_pos = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y / 2)
	var local_target = hand_container.get_global_transform().affine_inverse() * center_pos
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(selected_card, "position", local_target - Vector2(220, 330) / 2, 0.3)
	tween.tween_property(selected_card, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(selected_card, "rotation", 0, 0.3)
	
	# 選択した時点で暗転を開始し、確定ボタンを有効化する
	dimmer.visible = true
	confirm_button.disabled = false

func _on_confirm_button_pressed():
	if selected_card == null or is_janken_phase: return
	
	is_janken_phase = true
	confirm_button.disabled = true
	
	# 確定したタイミングで暗転
	dimmer.visible = true
	
	# 残りの手札を画面下に隠す
	var cards = hand_container.get_children()
	var hide_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for card in cards:
		if card != selected_card:
			hide_tween.tween_property(card, "position:y", 1000, 0.4)
			hide_tween.tween_property(card, "modulate:a", 0.0, 0.4)
	
	# 少し待つ（手札が消えるまでのラグ）
	await get_tree().create_timer(0.3).timeout
	
	# カードの基準サイズ
	var base_card_size = Vector2(220, 330)
	var p_target = player_duel_pos.global_position - (base_card_size * 1.2) / 2
	var e_target = enemy_duel_pos.global_position - (base_card_size * 1.2) / 2
	
	# プレイヤーの選択した手をDuelUIに移動
	selected_card.get_parent().remove_child(selected_card)
	$DuelUI.add_child(selected_card)
	selected_card.set_facing(false) # 裏向き
	selected_card.global_position = p_target # 最初から目標位置に置く
	
	# 敵の手をランダムに決定
	var enemy_hand_idx = randi() % enemy_hands.size()
	var enemy_hand_data = enemy_hands[enemy_hand_idx]
	
	# 敵のバトル用カードを生成
	var enemy_card = CARD_SCENE.instantiate()
	$DuelUI.add_child(enemy_card)
	enemy_card.set_hand_data(enemy_hand_data)
	enemy_card.set_facing(false) # 裏向き
	enemy_card.anchors_preset = Control.PRESET_TOP_LEFT
	enemy_card.global_position = e_target # 最初から目標位置に置く
	
	# 登場演出（ドン！）の初期状態セット
	selected_card.scale = Vector2(3.0, 3.0)
	selected_card.modulate.a = 0.0
	enemy_card.scale = Vector2(3.0, 3.0)
	enemy_card.modulate.a = 0.0
	
	var duel_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# プレイヤーカード着地
	duel_tween.tween_property(selected_card, "scale", Vector2(1.2, 1.2), 0.3)
	duel_tween.tween_property(selected_card, "modulate:a", 1.0, 0.15)
	
	# 敵カード着地
	duel_tween.tween_property(enemy_card, "scale", Vector2(1.2, 1.2), 0.3)
	duel_tween.tween_property(enemy_card, "modulate:a", 1.0, 0.15)
	
	# 着地後に一呼吸おいてめくる
	duel_tween.set_parallel(false)
	duel_tween.tween_interval(0.4)
	duel_tween.tween_callback(func(): 
		selected_card.flip_to_front()
		enemy_card.flip_to_front()
	)

func deselect_card():
	if selected_card == null or is_janken_phase: return
	
	selected_card.is_selected = false
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(selected_card, "scale", Vector2(1.0, 1.0), 0.3)
	
	selected_card.z_index = 0
	selected_card = null
	dimmer.visible = false
	confirm_button.disabled = true
	arrange_cards()

func _on_dimmer_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		deselect_card()

func arrange_cards(hovered_card: Control = null):
	var cards = hand_container.get_children()
	var card_count = cards.size()
	if card_count == 0: return
	
	var angle_step = 9.0
	var total_angle = angle_step * (card_count - 1)
	var start_angle = -total_angle / 2.0
	var radius = 1400.0
	var base_pos = Vector2(hand_container.size.x / 2, hand_container.size.y)
	
	for i in range(card_count):
		var card = cards[i]
		if card == selected_card: continue
		
		var angle_deg = start_angle + i * angle_step
		if hovered_card != null and hovered_card != selected_card:
			var hovered_idx = cards.find(hovered_card)
			if i < hovered_idx: angle_deg -= 1.5
			elif i > hovered_idx: angle_deg += 1.5
		
		var angle_rad = deg_to_rad(angle_deg)
		var x = sin(angle_rad) * radius
		var y = -cos(angle_rad) * radius + radius
		var target_pos = base_pos + Vector2(x, y) - Vector2(220, 330) / 2
		
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position", target_pos, 0.15)
		tween.tween_property(card, "rotation", angle_rad, 0.15)

func update_hp_ui():
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_current_hp
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_current_hp
	player_hp_label.text = str(player_current_hp) + " / " + str(player_max_hp)
