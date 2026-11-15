class_name KeeperDef
extends Resource
## 守鼎人：开局阵容、开局镇鼎符、战斗内被动效果与一个主动技能。

@export var id: StringName
## 选择界面里的排列顺序。
@export var order: int = 0
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var starting_beasts: Array[StringName] = []
@export var starting_talismans: int = 5
## 每场战斗都生效，和法宝一样注册到效果系统。
@export var passives: Array[EffectDef] = []
@export var skill: SkillDef

@export_group("解锁")
## "" 一开始可用；"bestiary" 图鉴收录满 unlock_value 只；"defeat" 击败过首领 unlock_param。
@export var unlock_kind: StringName = &""
@export var unlock_value: int = 0
@export var unlock_param: StringName = &""
@export_multiline var unlock_hint: String = ""
