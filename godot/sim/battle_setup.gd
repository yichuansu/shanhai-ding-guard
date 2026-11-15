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
