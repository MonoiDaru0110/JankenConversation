extends Resource
class_name HandData

enum Hand { ROCK, PAPER, SCISSORS }

@export var hand_type: Hand = Hand.ROCK
@export var attack_power: int = 0
@export var defense_power: int = 0
# 後ほどアビリティ欄を追加予定
