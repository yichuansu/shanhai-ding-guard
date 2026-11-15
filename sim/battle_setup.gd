class_name BattleSetup
extends RefCounted
## 开一场守鼎战需要的、来自一局（RunState）的输入。

var roster: Array[BeastInstance] = []
var relics: Array[RelicDef] = []
var ding_hp := 10
var ding_max := 10
## 本场可用的镇鼎符（已按每场上限截断）。
var talismans := 3
var seed_value := 0
var keeper: KeeperDef
## 敌人血量总倍率。随路线图深入递增，见 RunState.difficulty_scale()。
var hp_scale := 1.0
## 首领的血量倍率。首领血量按绝对值调，只随州数放大，不随路线图层数放大。
var boss_hp_scale := 1.0
## 开局灵气的加减（鼎劫）。
var spirit_delta := 0
## 敌人移速倍率（鼎劫）。
var speed_scale := 1.0
var formations: Array[FormationDef] = []
