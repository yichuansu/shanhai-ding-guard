class_name BeastDef
extends Resource
## 一只异兽。同一份数据既是敌人（被打、可捕获），也是塔（部署后攻击）。
## 长度单位是 1920×1080 设计像素，速度按每秒填写，模拟按 10Hz 换算。

enum Role { RANGED, AREA, GUARD, AUSPICIOUS }
## RARE 只能靠炼鼎融合获得，不会作为敌人出现。追加在末尾，保证已存的 .tres 数值不变。
enum Rarity { MINION, COMMON, ELITE, BOSS, RARE }

@export var id: StringName
@export var display_name: String = ""
@export var name_en: String = ""
@export var element: StringName = &"tu"
@export var role: Role = Role.RANGED
@export var rarity: Rarity = Rarity.COMMON
## 《山海经》原文摘录，图鉴展示用。
@export_multiline var lore: String = ""

@export_group("作为敌人")
@export var max_hp: int = 60
@export var move_speed: float = 100.0
@export var leak_damage: int = 1
@export var spirit_reward: int = 1
@export var shell_reward: int = 1
@export var capturable: bool = true
@export_range(0.0, 1.0) var capture_threshold: float = 0.25
## 被镇守异兽挡住时，每拍对它造成的伤害。
@export var contact_damage: float = 0.5

@export_group("作为塔")
@export var deploy_cost: int = 6
@export var damage: int = 10
@export var attack_range: float = 260.0
@export var attack_interval_ticks: int = 8
@export var projectile_speed: float = 600.0
@export_range(0.0, 1.0) var crit_chance: float = 0.0
@export var crit_multiplier: float = 2.0
@export_subgroup("镇守")
## 大于 0 即为镇守型：在离鼎位最近的路径点上拦截敌人。
@export var guard_hp: int = 0
@export var block_count: int = 1
## 鼎位到路径的最远距离，超出则无法拦截（仍会攻击）。
@export var guard_reach: float = 220.0
## 被打垮后多少拍恢复。
@export var guard_recover_ticks: int = 50
@export_subgroup("")
## 作为敌人时的技能（首领机制）：periodic / stun_towers、hp_below / summon。
@export var abilities: Array[EffectDef] = []
## "见则"特性。
@export var traits: Array[EffectDef] = []
