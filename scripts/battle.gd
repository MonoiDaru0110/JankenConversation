extends Control

# 戦闘情報の管理
@export var enemy_data: EnemyData
var enemy_current_hp: int
var current_enemy_max_hp: int = 10
var current_enemy_hands: Array[HandData] = []

@export var player_max_hp: int = 10
var player_current_hp: int

# 手の情報を管理 (HandData Resourceを使用)
@export var player_hands: Array[HandData] = []

@onready var enemy_name_label = $EnemyUI/EnemyNameLabel
@onready var enemy_hp_bar = %EnemyHPBar
@onready var enemy_hp_under_bar = $EnemyUI/EnemyHPContainer/EnemyHPUnderBar
@onready var enemy_hand_container = $EnemyHandContainer
@onready var enemy_illustration = $EnemyIllustration
@onready var background_node = $Background

# 移動後のパス
@onready var player_hp_bar = %PlayerHPBar
@onready var player_hp_under_bar = $DuelUI/PlayerHPContainer/PlayerHPUnderBar
@onready var player_hp_label = $DuelUI/PlayerHPContainer/PlayerHPLabel
@onready var hand_container = $PlayerUI/HandContainer
@onready var confirm_button = $DuelUI/ConfirmButton
@onready var talk_ui = $TalkUI

@onready var dimmer = $Dimmer
@onready var enemy_speech_bubble = $EnemySpeechBubble
@onready var player_speech_bubble = $PlayerSpeechBubble
@onready var enemy_duel_pos = $DuelUI/EnemyDuelPos
@onready var player_duel_pos = $DuelUI/PlayerDuelPos
@onready var talk_log_ui = $TalkLogUI
@onready var log_text_label = $TalkLogUI/PanelContainer/MarginContainer/ScrollContainer/LogText
@onready var log_toggle_button = $TalkLogUI/ToggleButton

var is_talking: bool = false
signal conversation_advanced

var active_ai_override: int = -1
var active_ai_flag: String = ""
var active_talk_category: String = ""
var active_talk_sub_option: String = ""

var talk_win_count: int = 0
var is_angry: bool = false
var last_player_hand: int = -1
var talk_performed_this_turn: bool = false




const COLOR_ROCK: String = "#4dadf7"
const COLOR_PAPER: String = "#40c057"
const COLOR_SCISSORS: String = "#ff6b6b"

const CARD_SCENE = preload("res://scenes/card.tscn")

# テキスト内の「グー」「チョキ」「パー」を自動で色付き太字にする
func format_hand_tags(text: String) -> String:
	if text == "": return ""
	var formatted = text
	formatted = formatted.replace("グー", "[color=" + COLOR_ROCK + "][b]グー[/b][/color]")
	formatted = formatted.replace("パー", "[color=" + COLOR_PAPER + "][b]パー[/b][/color]")
	formatted = formatted.replace("チョキ", "[color=" + COLOR_SCISSORS + "][b]チョキ[/b][/color]")
	return formatted

var selected_card: Control = null
var is_janken_phase: bool = false
var is_game_over: bool = false
var button_pulse_tween: Tween

func _ready():
	setup_battle()
	if dimmer: dimmer.gui_input.connect(_on_dimmer_gui_input)
	if talk_ui: talk_ui.talk_performed.connect(_on_talk_performed)
	
	# 会話ログの開閉ボタンの接続
	if talk_log_ui and log_toggle_button:
		log_toggle_button.pressed.connect(_on_log_toggle_pressed)
	
	if confirm_button: 

		confirm_button.pressed.connect(_on_confirm_button_pressed)
		# ボタンの中心をピボットにする
		confirm_button.pivot_offset = confirm_button.size / 2
		confirm_button.visible = false
	
	# 右クリックでのキャンセル用
	set_process_unhandled_input(true)

func setup_battle():
	var e_name = "大魔王 ジャキドウ"
	var e_hp = 10
	var e_hands: Array[HandData] = []
	
	if enemy_data:
		e_name = enemy_data.name
		e_hp = enemy_data.max_hp
		e_hands = enemy_data.base_hands.duplicate()
		if enemy_illustration and enemy_data.illustration:
			enemy_illustration.texture = enemy_data.illustration
		if background_node and enemy_data.battle_background:
			background_node.texture = enemy_data.battle_background
	
	current_enemy_max_hp = e_hp
	enemy_current_hp = e_hp
	player_current_hp = player_max_hp
	
	enemy_name_label.text = e_name
	
	# 敵の手札の初期化（データが不十分な場合）
	if e_hands.is_empty():
		for i in range(3):
			var data = HandData.new()
			data.hand_type = i as HandData.Hand
			data.attack_power = 8 + i
			data.defense_power = 3 + i
			e_hands.append(data)
	
	current_enemy_hands = e_hands
	
	# 敵の手札の表示
	for child in enemy_hand_container.get_children(): child.queue_free()
	for hand_data in current_enemy_hands:
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
	if is_janken_phase or is_game_over: return
	
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
	confirm_button.visible = true
	confirm_button.disabled = false
	
	# カードの右側にボタンを配置
	var card_width_scaled = 220 * 1.5
	confirm_button.global_position = center_pos + Vector2(card_width_scaled / 2 + 60, -confirm_button.size.y / 2)
	
	start_button_pulse()

func _on_confirm_button_pressed():
	if selected_card == null or is_janken_phase or is_game_over: return
	
	is_janken_phase = true
	confirm_button.disabled = true
	stop_button_pulse()
	
	# 確定したタイミングで暗転
	dimmer.visible = true
	confirm_button.visible = false
	
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
	
	# 敵の手を心理戦AIフラグを考慮して決定
	var enemy_hand_idx = -1
	
	if active_ai_override != -1:
		# 指定された手がある場合、敵の手札にそれがあれば出す
		for i in range(current_enemy_hands.size()):
			if current_enemy_hands[i].hand_type == active_ai_override:
				enemy_hand_idx = i
				break
				
	if enemy_hand_idx == -1 and active_ai_flag == "BELIEVE":
		# プレイヤーが「教える(TELL)」で言った手を完全に信じ、それに勝つ手を選択する
		var expected_player_hand = -1
		if active_talk_category == "TELL":
			if active_talk_sub_option == "ROCK": expected_player_hand = 0 # HandData.Hand.ROCK
			elif active_talk_sub_option == "PAPER": expected_player_hand = 1 # HandData.Hand.PAPER
			elif active_talk_sub_option == "SCISSORS": expected_player_hand = 2 # HandData.Hand.SCISSORS
		
		if expected_player_hand != -1:
			# プレイヤーの手に勝つ手：(プレイヤーの手 + 1) % 3
			var counter_hand = (expected_player_hand + 1) % 3
			# 敵の手札から counter_hand を探す
			for i in range(current_enemy_hands.size()):
				if current_enemy_hands[i].hand_type == counter_hand:
					enemy_hand_idx = i
					break
					
	if enemy_hand_idx == -1 and active_ai_flag == "ANGRY_COUNTER":
		# 怒り時：ひとつ前のじゃんけんでプレイヤーが出した手に勝つ手を出す
		if last_player_hand != -1:
			var counter_hand = (last_player_hand + 1) % 3
			for i in range(current_enemy_hands.size()):
				if current_enemy_hands[i].hand_type == counter_hand:
					enemy_hand_idx = i
					break
					
	if enemy_hand_idx == -1 and active_ai_flag == "PANIC":
		# 予定していた手（ランダムに決めた手）から、動揺して別の手に変更する
		var orig_idx = randi() % current_enemy_hands.size()
		var candidates = []
		for i in range(current_enemy_hands.size()):
			if i != orig_idx:
				candidates.append(i)
		if candidates.size() > 0:
			enemy_hand_idx = candidates[randi() % candidates.size()]
		else:
			enemy_hand_idx = orig_idx
			
	# 特殊なAI指示がない、または手札に対象の手がなかった場合のフォールバック（通常ランダムAI）
	if enemy_hand_idx == -1:
		enemy_hand_idx = randi() % current_enemy_hands.size()
		
	var enemy_hand_data = current_enemy_hands[enemy_hand_idx]
	
	# 次のターンのために心理戦AIフラグをリセット
	active_ai_override = -1
	active_ai_flag = ""
	
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
	
	# じゃんけん結果を会話ログに追加
	var p_hand_name = "グー"
	if p_type == 1: p_hand_name = "パー"
	elif p_type == 2: p_hand_name = "チョキ"
	
	var e_hand_name = "グー"
	if e_type == 1: e_hand_name = "パー"
	elif e_type == 2: e_hand_name = "チョキ"
	
	var outcome_log = "[color=#a28d75] ⚔ じゃんけん結果 ⚔[/color]\n"
	outcome_log += "あなた（%s） vs %s（%s）\n" % [p_hand_name, enemy_name_label.text, e_hand_name]
	if result == 1:
		outcome_log += "[color=#35c0a0][b]あなたの勝利！[/b][/color] (敵に %d ダメージ)" % e_damage
	elif result == 2:
		outcome_log += "[color=#eb7a94][b]%sの勝利！[/b][/color] (あなたに %d ダメージ)" % [enemy_name_label.text, p_damage]
	else:
		outcome_log += "[color=#d1a153][b]あいこ！[/b][/color] (あなた: %d ダメージ / 敵: %d ダメージ)" % [p_damage, e_damage]
	
	add_to_talk_log("", false, outcome_log)
	
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
	
	# 使用したプレイヤーの手を記憶 (直前のターンにプレイヤーが出した手)
	last_player_hand = p_type
	
	# 会話実行ターンの勝利数をカウントして怒り状態へ移行
	if talk_performed_this_turn:
		if result == 1: # プレイヤーの勝利
			talk_win_count += 1
			print("会話ターン勝利カウント: ", talk_win_count)
			if talk_win_count >= 3 and not is_angry:
				is_angry = true
				print("敵が怒り状態に移行しました！")
				
	# 決着時のセリフ演出の再生 (あいこ以外)
	if result == 1 or result == 2:
		var outcome_text = ""
		# リソースからの取得を試みる
		if enemy_data and enemy_data.dialogue_data:
			var diag = enemy_data.dialogue_data
			if result == 1: # プレイヤー勝利 (敵敗北)
				outcome_text = diag.lose_reaction_angry if is_angry else diag.lose_reaction_normal
			else: # 敵勝利 (プレイヤー敗北)
				outcome_text = diag.win_reaction_angry if is_angry else diag.win_reaction_normal
		else:
			# 【フォールバック】デフォルトの勝敗セリフ
			if result == 1:
				outcome_text = "もー！なんで負けちゃうの！？！？" if is_angry else "あっ…負けちゃった。"
			else:
				outcome_text = "あっ、勝てた…" if is_angry else "やったー！私の勝ちだ！"
				
		# 吹き出し表示演出 (非同期で再生し、プレイヤーの手札復帰をブロックしない)
		if outcome_text != "":
			var is_shake = is_angry and result == 1
			play_outcome_dialogue(outcome_text, is_shake)
			
	# 今ターンの会話フラグをリセット
	talk_performed_this_turn = false
	
	
	if enemy_current_hp <= 0:
		show_battle_result("敵を倒した！")
		return
	elif player_current_hp <= 0:
		show_battle_result("ゲームオーバー…")
		return
	
	# 手札の復帰
	restore_hand()
	talk_ui.reset_turn()

func play_outcome_dialogue(outcome_text: String, is_shake: bool):
	if outcome_text == "": return
	
	if is_shake:
		shake_screen(8.0, 0.25)
		
	enemy_speech_bubble.show_bubble(format_hand_tags(outcome_text))
	
	# セリフ送り（タイピング）の終了を待つ
	var elapsed = 0.0
	while enemy_speech_bubble.is_typing and elapsed < 1.8:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		
	# 1.2秒の余韻の後に吹き出しを隠す
	await get_tree().create_timer(1.2).timeout
	enemy_speech_bubble.hide_bubble()

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
	confirm_button.visible = false
	confirm_button.disabled = true
	stop_button_pulse()
	arrange_cards()

func _on_dimmer_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if is_talking:
			_on_conversation_click()
		else:
			deselect_card()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if is_talking:
			_on_conversation_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
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
	enemy_hp_bar.max_value = current_enemy_max_hp
	enemy_hp_under_bar.max_value = current_enemy_max_hp
	player_hp_bar.max_value = player_max_hp
	player_hp_under_bar.max_value = player_max_hp
	
	# 本体のバーを即座に更新
	enemy_hp_bar.value = enemy_current_hp
	player_hp_bar.value = player_current_hp
	
	# ラベルの更新
	player_hp_label.text = str(player_current_hp) + " / " + str(player_max_hp)
	
	# 背後の黄色いバー（残影）を少し遅れて追いかけさせる（最初は速く、徐々にゆっくり）
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy_hp_under_bar, "value", enemy_current_hp, 1.0).set_delay(0.4)
	tween.tween_property(player_hp_under_bar, "value", player_current_hp, 1.0).set_delay(0.4)

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

# リザルト表示
func show_battle_result(result_text: String):
	is_game_over = true
	talk_ui.hide()
	
	# 暗転（Dimmer）を最前面へ
	dimmer.visible = true
	dimmer.modulate.a = 0.0
	dimmer.z_index = 1000
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(dimmer, "modulate:a", 1.0, 0.5)
	
	# テキストラベルの生成
	var label = Label.new()
	label.text = result_text
	label.add_theme_font_size_override("font_size", 120)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	add_child(label)
	label.z_index = 1001
	label.modulate.a = 0.0
	label.scale = Vector2(0.5, 0.5)
	label.pivot_offset = label.size / 2 # この時点ではsizeが0の可能性があるので注意
	
	# サイズ確定後にピボット調整
	await get_tree().process_frame
	label.pivot_offset = label.size / 2
	
	var text_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	text_tween.tween_property(label, "modulate:a", 1.0, 0.5)
	text_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.5)

func _on_talk_performed(category: String, sub_option: String):
	if is_talking or is_janken_phase or is_game_over: return
	
	talk_performed_this_turn = true
	
	var player_text = ""
	var enemy_text = ""
	var reaction: DialogueReaction = null
	
	# リソースから対応する会話データを取得する試み
	if enemy_data and enemy_data.dialogue_data:
		var diag = enemy_data.dialogue_data
		if is_angry:
			# 怒り状態の会話データを取得
			if category == "TELL":
				if sub_option == "ROCK": reaction = diag.angry_tell_rock
				elif sub_option == "SCISSORS": reaction = diag.angry_tell_scissors
				elif sub_option == "PAPER": reaction = diag.angry_tell_paper
			elif category == "ASK":
				if sub_option == "ROCK?": reaction = diag.angry_ask_rock
				elif sub_option == "SCISSORS?": reaction = diag.angry_ask_scissors
				elif sub_option == "PAPER?": reaction = diag.angry_ask_paper
				elif sub_option == "WHAT?": reaction = diag.angry_ask_what
			elif category == "CHAT":
				if diag.angry_chat_reactions.size() > 0:
					reaction = diag.angry_chat_reactions[randi() % diag.angry_chat_reactions.size()]
		else:
			# 通常状態の会話データを取得
			if category == "TELL":
				if sub_option == "ROCK": reaction = diag.tell_rock
				elif sub_option == "SCISSORS": reaction = diag.tell_scissors
				elif sub_option == "PAPER": reaction = diag.tell_paper
			elif category == "ASK":
				if sub_option == "ROCK?": reaction = diag.ask_rock
				elif sub_option == "SCISSORS?": reaction = diag.ask_scissors
				elif sub_option == "PAPER?": reaction = diag.ask_paper
				elif sub_option == "WHAT?": reaction = diag.ask_what
			elif category == "CHAT":
				if diag.chat_reactions.size() > 0:
					reaction = diag.chat_reactions[randi() % diag.chat_reactions.size()]
					
	# リソースから会話反応が取得できた場合の適用
	if reaction != null:
		player_text = reaction.player_line
		enemy_text = reaction.enemy_line
		active_ai_override = reaction.ai_action_override
		active_ai_flag = reaction.ai_behavior_flag
		active_talk_category = category
		active_talk_sub_option = sub_option
		
		# 動的透視 (MIND_READ) 挙動の処理
		if active_ai_flag == "MIND_READ":
			var expected_hand = 0
			if current_enemy_hands.size() > 0:
				expected_hand = current_enemy_hands[randi() % current_enemy_hands.size()].hand_type
			else:
				expected_hand = randi() % 3
				
			var hand_name = "グー"
			if expected_hand == 1: hand_name = "パー"
			elif expected_hand == 2: hand_name = "チョキ"
			
			# テンプレート "%s" を実際の選択手に置換
			if "%s" in enemy_text:
				enemy_text = enemy_text % hand_name
				
			active_ai_override = expected_hand
		
		# 怒り時のCHAT（雑談）で怒りを解除する
		if is_angry and category == "CHAT":
			is_angry = false
			talk_win_count = 0
	else:
		# 【フォールバック】Notionに基づく「素直な少女」のデフォルト仕様
		active_talk_category = category
		active_talk_sub_option = sub_option
		
		if not is_angry:
			# --- 通常時仕様 ---
			if category == "TELL":
				# 教える：Aを教えられたら、Aに勝つ手を出す（BELIEVE）
				var hand_name = "グー"
				if sub_option == "PAPER": hand_name = "パー"
				elif sub_option == "SCISSORS": hand_name = "チョキ"
				
				player_text = "次は" + hand_name + "を出すよ！本当だよ。"
				enemy_text = "えっ、" + hand_name + "ですか？教えてくれてありがとう！\n（それなら私は勝てる手を…）"
				active_ai_flag = "BELIEVE"
			elif category == "ASK":
				# 聞く：思考の透視。その場で敵の手(A)を決定し、Aを出させ、次のターンにそれを強制
				var expected_hand = 0
				if current_enemy_hands.size() > 0:
					expected_hand = current_enemy_hands[randi() % current_enemy_hands.size()].hand_type
				else:
					expected_hand = randi() % 3
					
				var hand_name = "グー"
				if expected_hand == 1: hand_name = "パー"
				elif expected_hand == 2: hand_name = "チョキ"
				
				enemy_text = "（次は" + hand_name + "を出そうかな…）"
				player_text = "（思考が筒抜けだ…よし、勝てる手を準備しよう）"
				
				active_ai_override = expected_hand
			elif category == "CHAT":
				player_text = "いい天気だね。じゃんけん、がんばろう。"
				enemy_text = "えへへ、そうですね！負けませんよ〜！（仮テキスト）"
				active_ai_flag = "" # 通常ランダム手
		else:
			# --- 怒り時仕様 ---
			if category == "TELL":
				# 教える：「絶対ウソついてるよね！？もう信じないから！」→前回のプレイヤーの手に勝つ手を出す
				player_text = "次は本気でいくからね。"
				enemy_text = "絶対ウソついてるよね！？もう信じないから！"
				active_ai_flag = "ANGRY_COUNTER"
			elif category == "ASK":
				# 聞く：(…)→プレイヤー(…)→前回のプレイヤーの手に勝つ手を出す
				player_text = "（…）"
				enemy_text = "（…）"
				active_ai_flag = "ANGRY_COUNTER"
			elif category == "CHAT":
				# 雑談：怒りが解除される（仮テキスト）→ランダムな手
				player_text = "落ち着いて、少しお話ししよう？"
				enemy_text = "うぅ…怒ってごめんなさい。もう怒ってないですよ。（仮テキスト・怒り解除）"
				
				is_angry = false
				talk_win_count = 0
				active_ai_flag = "" # ランダム手

	# 怒り時特有の演出：吹き出し登場のタイミングでカメラを激しく揺らす
	if is_angry and reaction == null and (category == "TELL" or category == "ASK"):
		# 怒りの激しさを画面シェイクで表現！
		shake_screen(12.0, 0.35)
		
	# 会話の演出を再生
	await play_conversation(player_text, enemy_text)


func play_conversation(player_text: String, enemy_text: String):
	is_talking = true
	
	# 元のディマーの色を保存し、完全に透明にして暗転を廃止（クリックガードは維持）
	var orig_color = dimmer.color
	dimmer.color = Color(0, 0, 0, 0)
	dimmer.visible = true
	
	# 手札をクリックできないようにマウスフィルターを調整
	var prev_filter = hand_container.mouse_filter
	hand_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# プレイヤーの発言
	player_speech_bubble.show_bubble(format_hand_tags(player_text))
	add_to_talk_log("あなた", true, player_text)
	await wait_for_step(player_speech_bubble)
	
	# 少し間を空ける
	await get_tree().create_timer(0.3).timeout
	
	# 敵のリアクション
	enemy_speech_bubble.show_bubble(format_hand_tags(enemy_text))
	add_to_talk_log(enemy_name_label.text, false, enemy_text)
	await wait_for_step(enemy_speech_bubble)
	
	# 最後のクリック待ち（または自動進行）
	await wait_for_click()
	
	# 吹き出しを閉じる
	player_speech_bubble.hide_bubble()
	enemy_speech_bubble.hide_bubble()
	
	# 閉じるアニメが終わるのを少し待つ
	await get_tree().create_timer(0.25).timeout
	
	dimmer.visible = false
	dimmer.color = orig_color # 元の色に戻す
	hand_container.mouse_filter = prev_filter
	is_talking = false

func wait_for_step(bubble: SpeechBubble):
	# bubbleのタイピングが終わるのを待つ
	while bubble.is_typing:
		await get_tree().process_frame
	
	# 表示完了後の余韻を待つ（最大1.8秒、クリックされれば即進む）
	var elapsed = 0.0
	var clicked = false
	var callable = func(): clicked = true
	conversation_advanced.connect(callable)
	
	while elapsed < 1.8 and not clicked:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		
	if conversation_advanced.is_connected(callable):
		conversation_advanced.disconnect(callable)

func wait_for_click():
	var clicked = false
	var callable = func(): clicked = true
	conversation_advanced.connect(callable)
	
	# 3秒経過でも自動で進むようにするが、クリック優先
	var elapsed = 0.0
	while elapsed < 3.0 and not clicked:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		
	if conversation_advanced.is_connected(callable):
		conversation_advanced.disconnect(callable)

func _on_conversation_click():
	if player_speech_bubble.is_typing:
		player_speech_bubble.skip_typing()
		return
	if enemy_speech_bubble.is_typing:
		enemy_speech_bubble.skip_typing()
		return
	
	conversation_advanced.emit()

func _on_log_toggle_pressed():
	var panel = talk_log_ui.get_node("PanelContainer")
	if panel:
		panel.visible = !panel.visible
		var btn_text = "▲ ログを開く" if not panel.visible else "▼ ログを隠す"
		log_toggle_button.text = btn_text
		log_toggle_button.release_focus()

func add_to_talk_log(speaker_name: String, is_player_speaker: bool, text: String):
	if text == "" or not log_text_label: return
	
	var formatted_text = format_hand_tags(text)
	
	if speaker_name == "":
		# 話者名が空の場合はシステムメッセージとしてそのまま追加
		log_text_label.text += formatted_text + "\n\n"
	else:
		var color_code = "#35c0a0" if is_player_speaker else "#eb7a94"
		var name_tag = "[color=" + color_code + "][b]" + speaker_name + "[/b][/color]"
		log_text_label.text += name_tag + ": " + formatted_text + "\n\n"
