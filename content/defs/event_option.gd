class_name EventOption
extends Resource
## 奇遇的一个选项。先付 cost_shells；按 success_chance 判定，成功执行 outcomes，失败执行 fail_outcomes。
## outcome 用 EffectDef 的一局级操作：gain_shells、heal_ding、lose_ding、ding_max、gain_talismans、
## gain_relic（param_id 为空则随机）、gain_beast（param_id）、tier_up_random。

@export var label: String = ""
@export_multiline var hint: String = ""
@export var cost_shells: int = 0
@export_range(0.0, 1.0) var success_chance: float = 1.0
@export var outcomes: Array[EffectDef] = []
@export var fail_outcomes: Array[EffectDef] = []
@export_multiline var success_text: String = ""
@export_multiline var fail_text: String = ""
