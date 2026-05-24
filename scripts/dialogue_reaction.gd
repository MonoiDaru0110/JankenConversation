extends Resource
class_name DialogueReaction

# 手札の列挙型を簡単に扱うための定数
# HandData.Hand に合わせて、ROCK=0, PAPER=1, SCISSORS=2, NONE=-1
enum ActionOverride {
	NONE = -1,
	ROCK = 0,
	PAPER = 1,
	SCISSORS = 2
}

@export_multiline var player_line: String = ""
@export_multiline var enemy_line: String = ""
@export var ai_action_override: ActionOverride = ActionOverride.NONE
@export var ai_behavior_flag: String = "" # "BELIEVE", "PANIC", "BLUFF" など
