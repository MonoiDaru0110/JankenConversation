extends Control
class_name SpeechBubble

@export var is_player: bool = false
@export var bubble_color: Color = Color(0.98, 0.96, 0.90, 0.95) # かわいいクリーム色
@export var border_color: Color = Color(0.92, 0.48, 0.58, 0.9)

@onready var bubble_panel = $BubblePanel
@onready var rich_text_label = $BubblePanel/MarginContainer/RichTextLabel
@onready var tail = $Tail

var active_tween: Tween
var is_typing: bool = false
var full_text: String = ""

func _ready():
	# 初期状態は非表示、縮小
	scale = Vector2.ZERO
	hide()
	
	# デザインの適用
	setup_theme()

func setup_theme():
	# 動的にStyleBoxFlatを作成し、パネルに設定
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bubble_color
	
	# テキストカラーをかわいい焦げ茶色（ダークブラウン）にして読みやすくする
	rich_text_label.add_theme_color_override("default_color", Color(0.22, 0.16, 0.10))
	
	# プレイヤーと敵で枠線の色を可愛く微調整
	if is_player:
		# プレイヤー：さわやかなパステルミントグリーン
		style_box.border_color = Color(0.35, 0.75, 0.60, 0.9)
	else:
		# 敵：あたたかみのあるパステルローズピンク
		style_box.border_color = Color(0.92, 0.48, 0.58, 0.9)
		
	# 太めの枠線にして丸みと可愛さを強調
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	
	style_box.corner_radius_top_left = 18
	style_box.corner_radius_top_right = 18
	style_box.corner_radius_bottom_left = 18
	style_box.corner_radius_bottom_right = 18
	
	# クリーム色に調和する淡く焦げ茶がかったソフトな影 (Rich Aesthetics)
	style_box.shadow_size = 10
	style_box.shadow_color = Color(0.22, 0.15, 0.08, 0.18)
	style_box.shadow_offset = Vector2(0, 5)
	
	bubble_panel.add_theme_stylebox_override("panel", style_box)
	
	# しっぽの色も吹き出し本体と合わせる
	tail.color = bubble_color
	
	# しっぽとピボット位置の設定
	adjust_tail_and_pivot()

func adjust_tail_and_pivot():
	# サイズ確定を待つ
	await get_tree().process_frame
	if not is_inside_tree(): return
	
	var w = size.x
	var h = size.y
	
	# しっぽのポリゴンを設定 (Polygon2D)
	# プレイヤー：右下から突き出る
	# 敵：左上または左下から突き出る（今回はイラストの横に配置されるため「左下」にする）
	if is_player:
		# 吹き出しの右下（X=幅-40, Y=高さ）から、右下に向けて三角形を突き出す
		var tail_origin = Vector2(w - 60, h - 2)
		tail.polygon = PackedVector2Array([
			tail_origin,
			tail_origin + Vector2(40, 0),
			tail_origin + Vector2(20, 25)
		])
		# しっぽの根元をピボット（拡縮の中心）にすることで、そこから膨らむ
		pivot_offset = tail_origin + Vector2(20, 0)
	else:
		# 吹き出しの左下（X=40, Y=高さ）から、左下に向けて三角形を突き出す
		var tail_origin = Vector2(40, h - 2)
		tail.polygon = PackedVector2Array([
			tail_origin,
			tail_origin + Vector2(-40, 0),
			tail_origin + Vector2(-20, 25)
		])
		pivot_offset = tail_origin + Vector2(-20, 0)

func show_bubble(text: String):
	full_text = text
	
	# 以前のTweenを消去
	if active_tween:
		active_tween.kill()
	
	# テキストを準備
	rich_text_label.text = text
	rich_text_label.visible_ratio = 0.0
	
	# 可視化してピボットを再計算
	show()
	adjust_tail_and_pivot()
	
	# ぷくっと膨らむ登場アニメーション (TRANS_BACK & EASE_OUT)
	scale = Vector2.ZERO
	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "scale", Vector2.ONE, 0.35)
	
	# 同時に文字のタイピングアニメーション
	is_typing = true
	var typing_speed = 0.04 # 1文字あたり0.04秒
	var duration = max(0.4, text.length() * typing_speed)
	
	var text_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	text_tween.tween_property(rich_text_label, "visible_ratio", 1.0, duration)
	text_tween.finished.connect(func(): is_typing = false)

func hide_bubble():
	if active_tween:
		active_tween.kill()
		
	is_typing = false
	
	# シュッと縮む消滅アニメーション (TRANS_CUBIC & EASE_IN)
	active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	active_tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	active_tween.finished.connect(func(): 
		hide()
	)

# クリック等でタイピングをスキップして全文表示
func skip_typing():
	if is_typing:
		is_typing = false
		rich_text_label.visible_ratio = 1.0
		# テキストアニメ用のタイピングTweenを探して止める必要があるが、
		# visible_ratio を 1.0 にすれば自然に完了扱いになる

func clear_bubble():
	if active_tween:
		active_tween.kill()
	scale = Vector2.ZERO
	hide()
	rich_text_label.text = ""
	is_typing = false
