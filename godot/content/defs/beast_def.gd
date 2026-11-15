class_name BeastDef
extends Resource
## 一只异兽。同一份数据既是敌人（被打、可捕获），也是塔（部署后攻击）。
## 长度单位是 1920×1080 设计像素，速度按每秒填写，模拟按 10Hz 换算。

enum Role { RANGED, AREA, GUARD, AUSPICIOUS }
enum Rarity { MINION, COMMON, ELITE, BOSS }

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

@export_group("作为塔")
@export var deploy_cost: int = 6
@export var damage: int = 10
@export var attack_range: float = 260.0
@export var attack_interval_ticks: int = 8
@export var projectile_speed: float = 600.0
## "见则"特性。
@export var traits: Array[EffectDef] = []
