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
@onready var enemy_hp_bar = %EnemyHPBar
@onready var enemy_hp_under_bar = $EnemyUI/EnemyHPContainer/EnemyHPUnderBar
@onready var enemy_hand_container = $EnemyHandContainer

# 移動後のパス
@onready var player_hp_bar = %PlayerHPBar
@onready var player_hp_under_bar = $DuelUI/PlayerHPContainer/PlayerHPUnderBar
@onready var player_hp_label = $DuelUI/PlayerHPContainer/PlayerHPLabel
@onready var hand_container = $PlayerUI/HandContainer
@onready var confirm_button = $DuelUI/ConfirmButton

@onready var dimmer = $Dimmer
@onready var enemy_duel_pos = $DuelUI/EnemyDuelPos
@onready var player_duel_pos = $DuelUI/PlayerDuelPos

var selected_card: Control = null
var is_janken_phase: bool = false
var button_pulse_tween: Tween

const CARD_SCENE = preload("res://scenes/card.tscn")

func _ready():
	setup_battle()
	if dimmer: dimmer.gui_input.connect(_on_dimmer_gui_input)
	if confirm_button: 
		confirm_button.pressed.connect(_on_confirm_button_pressed)
		# ボタンの中心をピボットにする
		confirm_button.pivot_offset = confirm_button.size / 2

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
	
	# 選択した時点で確定ボタンを有効化し、暗転を開始する
	dimmer.visible = true
	confirm_button.disabled = false
	start_button_pulse()

func _on_confirm_button_pressed():
	if selected_card == null or is_janken_phase: return
	
	is_janken_phase = true
	confirm_button.disabled = true
	stop_button_pulse()
	
	# 確定したタイミングで暗転
	dimmer.visible = true
	
	# すべての手札を画面下に隠す（選択中のカードも含む）
	var cards = hand_container.get_children()
	var hide_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for card in cards:
		hide_tween.tween_property(card, "position:y", 1000, 0.4)
		hide_tween.tween_property(card, "modulate:a", 0.0, 0.4)
	
	# 少し待つ（手札が消えるまでのラグ）
	await get_tree().create_timer(0.3).timeout
	
	# カードの基準サイズ
	var base_card_size = Vector2(220, 330)
	var p_target = player_duel_pos.global_position - (base_card_size * 1.2) / 2
	var e_target = enemy_duel_pos.global_position - (base_card_size * 1.2) / 2
	
	# プレイヤー用の対戦カードを新しく生成（手札のカードは使わない）
	var player_duel_card = CARD_SCENE.instantiate()
	$DuelUI.add_child(player_duel_card)
	player_duel_card.set_hand_data(selected_card.hand_data)
	player_duel_card.set_facing(false) # 裏向き
	player_duel_card.anchors_preset = Control.PRESET_TOP_LEFT
	player_duel_card.global_position = p_target
	player_duel_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_duel_card.slammed.connect(func(): shake_screen(10.0, 0.2)) # 叩きつけ時に揺らす
	
	# 敵の手をランダムに決定
	var enemy_hand_idx = randi() % enemy_hands.size()
	var enemy_hand_data = enemy_hands[enemy_hand_idx]
	
	# 敵のバトル用カードを生成
	var enemy_card = CARD_SCENE.instantiate()
	$DuelUI.add_child(enemy_card)
	enemy_card.set_hand_data(enemy_hand_data)
	enemy_card.set_facing(false) # 裏向き
	enemy_card.anchors_preset = Control.PRESET_TOP_LEFT
	enemy_card.global_position = e_target
	enemy_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_card.slammed.connect(func(): shake_screen(10.0, 0.2)) # 叩きつけ時に揺らす
	
	# 登場演出（ドン！）の初期状態セット
	player_duel_card.scale = Vector2(3.0, 3.0)
	player_duel_card.modulate.a = 0.0
	enemy_card.scale = Vector2(3.0, 3.0)
	enemy_card.modulate.a = 0.0
	
	var duel_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 両方のカードが同じ仕組みで着地
	duel_tween.tween_property(player_duel_card, "scale", Vector2(1.2, 1.2), 0.3)
	duel_tween.tween_property(player_duel_card, "modulate:a", 1.0, 0.15)
	
	duel_tween.tween_property(enemy_card, "scale", Vector2(1.2, 1.2), 0.3)
	duel_tween.tween_property(enemy_card, "modulate:a", 1.0, 0.15)
	
	# 着地後に一呼吸おいてめくる
	duel_tween.set_parallel(false)
	duel_tween.tween_interval(0.4)
	duel_tween.tween_callback(func(): 
		player_duel_card.flip_to_front()
		enemy_card.flip_to_front()
	)
	
	# めくった後に結果判定
	duel_tween.tween_interval(0.8)
	duel_tween.tween_callback(func(): resolve_janken_outcome(player_duel_card, enemy_card))

# 勝敗判定とダメージ処理
func resolve_janken_outcome(p_card, e_card):
	var p_type = p_card.hand_data.hand_type
	var e_type = e_card.hand_data.hand_type
	
	var p_atk = p_card.hand_data.attack_power
	var p_def = p_card.hand_data.defense_power
	var e_atk = e_card.hand_data.attack_power
	var e_def = e_card.hand_data.defense_power
	
	# 勝敗ロジック (0: Rock, 1: Paper, 2: Scissors)
	# (p - e + 3) % 3  =>  0: あいこ, 1: 勝ち, 2: 負け
	# ただし、HandData.Hand の定義順序に依存
	# 現在の定義: ROCK=0, PAPER=1, SCISSORS=2
	# PAPER(1)はROCK(0)に勝ち、SCISSORS(2)はPAPER(1)に勝ち、ROCK(0)はSCISSORS(2)に勝つ
	
	var result = (p_type - e_type + 3) % 3
	
	var p_damage = 0
	var e_damage = 0
	
	if result == 1: # プレイヤーの勝利
		e_damage = max(0, p_atk - e_def)
		print("プレイヤーの勝利！ 敵に ", e_damage, " ダメージ")
	elif result == 2: # 敵の勝利
		p_damage = max(0, e_atk - p_def)
		print("敵の勝利！ プレイヤーに ", p_damage, " ダメージ")
	else: # あいこ
		p_damage = max(0, e_atk - p_def)
		e_damage = max(0, p_atk - e_def)
		print("あいこ！ 互いにダメージ")
	
	# 攻撃アニメーションの再生
	await play_attack_animation(p_card, e_card, result)
	
	# 激突の瞬間にカードと暗転を消去
	p_card.queue_free()
	e_card.queue_free()
	dimmer.visible = false
	is_janken_phase = false
	
	# 使用した手札の状態をリセット
	if selected_card:
		selected_card.is_selected = false
		selected_card.z_index = 0
		selected_card.scale = Vector2(1.0, 1.0)
		selected_card = null
	
	# エネルギー弾とダメージ表記の演出
	await show_damage_effects(p_damage, e_damage)
	
	# 手札の復帰
	restore_hand()

# 攻撃アニメーション（予備動作 -> 衝突）
func play_attack_animation(p_card, e_card, result):
	var p_orig_pos = p_card.global_position
	var e_orig_pos = e_card.global_position
	
	# 目標地点と助走距離の計算
	var p_pull_dist = 0.0
	var e_pull_dist = 0.0
	var p_impact_y = p_orig_pos.y
	var e_impact_y = e_orig_pos.y
	
	if result == 1: # プレイヤー勝利
		p_pull_dist = 100.0 # 大きく引く
		p_impact_y = e_orig_pos.y + 50.0 # 相手のところまで踏み込む
	elif result == 2: # 敵勝利
		e_pull_dist = 100.0
		e_impact_y = p_orig_pos.y - 50.0
	else: # あいこ
		p_pull_dist = 40.0
		e_pull_dist = 40.0
		var center_y = (p_orig_pos.y + e_orig_pos.y) / 2
		p_impact_y = center_y + 40.0
		e_impact_y = center_y - 40.0

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	
	# 1. 助走（勝った側のみ、またはあいこなら両方）
	if p_pull_dist > 0:
		tween.tween_property(p_card, "global_position:y", p_orig_pos.y + p_pull_dist, 0.4)
	if e_pull_dist > 0:
		tween.tween_property(e_card, "global_position:y", e_orig_pos.y - e_pull_dist, 0.4)
	
	await tween.finished
	
	# 2. 衝突（勝った側が踏み込む）
	var impact_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(p_card, "global_position:y", p_impact_y, 0.1)
	impact_tween.tween_property(e_card, "global_position:y", e_impact_y, 0.1)
	
	await impact_tween.finished
	
	# 衝突の瞬間に強めのシェイク
	shake_screen(25.0 if result != 0 else 15.0, 0.2)
	
	# そのまま消滅させるため、元の位置に戻る処理は削除

# エネルギー弾とダメージ数字の演出
func show_damage_effects(p_dmg: int, e_dmg: int):
	var impact_pos = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y / 2)
	
	if e_dmg > 0 and p_dmg > 0:
		# あいこの場合：同時に飛ばす（警告回避のためラムダ経由で開始）
		var fire_e = func(): await spawn_projectile_and_damage(impact_pos, enemy_hp_bar.global_position + enemy_hp_bar.size/2, e_dmg, false)
		var fire_p = func(): await spawn_projectile_and_damage(impact_pos, player_hp_bar.global_position + player_hp_bar.size/2, p_dmg, true)
		fire_e.call()
		fire_p.call()
		# 演出が終わるまで待機
		await get_tree().create_timer(1.2).timeout
	elif e_dmg > 0:
		await spawn_projectile_and_damage(impact_pos, enemy_hp_bar.global_position + enemy_hp_bar.size/2, e_dmg, false)
	elif p_dmg > 0:
		await spawn_projectile_and_damage(impact_pos, player_hp_bar.global_position + player_hp_bar.size/2, p_dmg, true)
	else:
		await get_tree().create_timer(0.5).timeout

# 弾を飛ばしてダメージを与える
func spawn_projectile_and_damage(start_pos: Vector2, end_pos: Vector2, dmg: int, is_player: bool):
	# 弾の生成
	var proj = ColorRect.new()
	proj.size = Vector2(20, 20)
	proj.pivot_offset = Vector2(10, 10)
	proj.color = Color.WHITE
	add_child(proj)
	proj.global_position = start_pos - proj.size/2
	
	# 弾の移動
	var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(proj, "global_position", end_pos - proj.size/2, 0.4)
	await tween.finished
	proj.queue_free()
	
	# 着弾時の演出
	shake_screen(8.0, 0.1)
	spawn_damage_popup(end_pos, dmg)
	
	# HP反映
	if is_player:
		player_current_hp = max(0, player_current_hp - dmg)
	else:
		enemy_current_hp = max(0, enemy_current_hp - dmg)
	update_hp_ui()
	
	await get_tree().create_timer(0.5).timeout

# ダメージ数字のポップアップ
func spawn_damage_popup(pos: Vector2, amount: int):
	var label = Label.new()
	label.text = str(amount) + "!"
	label.add_theme_font_size_override("font_size", 80)
	label.add_theme_color_override("font_color", Color.RED if amount > 0 else Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	add_child(label)
	
	# サイズ確定を待ってから中央揃え
	await get_tree().process_frame
	label.global_position = pos - Vector2(label.size.x / 2, 80)
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# 0.4秒待ってから上昇開始。透明度はより早く消えるように調整
	tween.tween_property(label, "global_position:y", label.global_position.y - 200, 1.2).set_delay(0.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.5)
	
	tween.finished.connect(func(): label.queue_free())

func restore_hand():
	var cards = hand_container.get_children()
	var restore_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	for card in cards:
		card.modulate.a = 0.0
		restore_tween.tween_property(card, "modulate:a", 1.0, 0.5)
	
	# カードの再整列（位置を戻す）
	arrange_cards()

func apply_damage(p_dmg: int, e_dmg: int):
	player_current_hp = max(0, player_current_hp - p_dmg)
	enemy_current_hp = max(0, enemy_current_hp - e_dmg)
	update_hp_ui()

func deselect_card():
	if selected_card == null or is_janken_phase: return
	
	selected_card.is_selected = false
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(selected_card, "scale", Vector2(1.0, 1.0), 0.3)
	
	selected_card.z_index = 0
	selected_card = null
	dimmer.visible = false
	confirm_button.disabled = true
	stop_button_pulse()
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
	# 最大値のセット
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_under_bar.max_value = enemy_max_hp
	player_hp_bar.max_value = player_max_hp
	player_hp_under_bar.max_value = player_max_hp
	
	# 本体のバーを即座に更新
	enemy_hp_bar.value = enemy_current_hp
	player_hp_bar.value = player_current_hp
	
	# ラベルの更新
	player_hp_label.text = str(player_current_hp) + " / " + str(player_max_hp)
	
	# 背後の黄色いバー（残影）を少し遅れて追いかけさせる
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy_hp_under_bar, "value", enemy_current_hp, 0.6).set_delay(0.4)
	tween.tween_property(player_hp_under_bar, "value", player_current_hp, 0.6).set_delay(0.4)

func start_button_pulse():
	if button_pulse_tween: button_pulse_tween.kill()
	button_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	button_pulse_tween.tween_property(confirm_button, "scale", Vector2(1.1, 1.1), 0.6)
	button_pulse_tween.tween_property(confirm_button, "scale", Vector2(1.0, 1.0), 0.6)

func stop_button_pulse():
	if button_pulse_tween: button_pulse_tween.kill()
	confirm_button.scale = Vector2(1.0, 1.0)

# 画面を揺らす演出
func shake_screen(intensity: float, duration: float):
	var original_pos = position
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 数回ランダムな方向に揺らす
	for i in range(5):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(self, "position", original_pos + offset, duration / 6.0)
	
	# 最後に元の位置に戻す
	tween.tween_property(self, "position", original_pos, duration / 6.0)
