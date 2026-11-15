class_name MapNode
extends RefCounted
## 路线图上的一个节点。

enum Type { BATTLE, ELITE, EVENT, SHOP, FORGE, REST, BOSS }

const DISPLAY := {
	Type.BATTLE: "战斗",
	Type.ELITE: "精英",
	Type.EVENT: "奇遇",
	Type.SHOP: "集市",
	Type.FORGE: "炼鼎",
	Type.REST: "祭祀",
	Type.BOSS: "首领",
}

var id := 0
var layer := 0
var column := 0
## 0..1 的横向位置，用来连线和排版。
var x := 0.5
var type: Type = Type.BATTLE
var next := PackedInt32Array()


func is_combat() -> bool:
	return type == Type.BATTLE or type == Type.ELITE or type == Type.BOSS
