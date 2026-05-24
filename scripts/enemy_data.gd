extends Resource
class_name EnemyData

@export var name: String = "敵の名前"
@export var illustration: Texture2D
@export var battle_background: Texture2D
@export var max_hp: int = 10
@export var base_hands: Array[HandData] = []
@export var dialogue_data: EnemyDialogueData
