extends Resource
class_name EnemyDialogueData

@export_category("通常状態 (Normal State)")
@export_group("TELL (教える)")
@export var tell_rock: DialogueReaction
@export var tell_scissors: DialogueReaction
@export var tell_paper: DialogueReaction

@export_group("ASK (尋ねる)")
@export var ask_rock: DialogueReaction
@export var ask_scissors: DialogueReaction
@export var ask_paper: DialogueReaction
@export var ask_what: DialogueReaction

@export_group("CHAT (雑談)")
@export var chat_reactions: Array[DialogueReaction] = []

@export_category("怒り状態 (Angry State)")
@export_group("TELL (教える)")
@export var angry_tell_rock: DialogueReaction
@export var angry_tell_scissors: DialogueReaction
@export var angry_tell_paper: DialogueReaction

@export_group("ASK (尋ねる)")
@export var angry_ask_rock: DialogueReaction
@export var angry_ask_scissors: DialogueReaction
@export var angry_ask_paper: DialogueReaction
@export var angry_ask_what: DialogueReaction

@export_group("CHAT (雑談)")
@export var angry_chat_reactions: Array[DialogueReaction] = []

@export_category("勝敗リアクション (Battle Outcomes)")
@export_group("通常時 (Normal State)")
@export var win_reaction_normal: String = "やったー！私の勝ちだ！"
@export var lose_reaction_normal: String = "あっ…負けちゃった。"

@export_group("怒り時 (Angry State)")
@export var win_reaction_angry: String = "あっ、勝てた…"
@export var lose_reaction_angry: String = "もー！なんで負けちゃうの！？！？"
