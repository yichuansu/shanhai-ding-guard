class_name Elements
extends RefCounted
## 五行的固定关系（典籍设定，不随平衡改动）。倍率数字在 ElementChart 里。

const MU := &"mu"
const HUO := &"huo"
const TU := &"tu"
const JIN := &"jin"
const SHUI := &"shui"
const NONE := &"none"

const ALL: Array[StringName] = [MU, HUO, TU, JIN, SHUI]

## 克：键克值。
const OVERCOMES := {
	&"mu": &"tu",
	&"tu": &"shui",
	&"shui": &"huo",
	&"huo": &"jin",
	&"jin": &"mu",
}

## 生：键生值。
const GENERATES := {
	&"mu": &"huo",
	&"huo": &"tu",
	&"tu": &"jin",
	&"jin": &"shui",
	&"shui": &"mu",
}

const DISPLAY := {
	&"mu": "木",
	&"huo": "火",
	&"tu": "土",
	&"jin": "金",
	&"shui": "水",
	&"none": "无",
}

## 传统五色：木青、火赤、土黄、金白、水黑。只给玩法信息用。
const COLORS := {
	&"mu": Color("2f7d5a"),
	&"huo": Color("b9402c"),
	&"tu": Color("b8892e"),
	&"jin": Color("c9d0d4"),
	&"shui": Color("26384d"),
	&"none": Color("6b6b6b"),
}


static func overcomes(attacker: StringName, defender: StringName) -> bool:
	return OVERCOMES.get(attacker, &"") == defender


static func generates(source: StringName, target: StringName) -> bool:
	return GENERATES.get(source, &"") == target


static func is_valid(element: StringName) -> bool:
	return element in ALL or element == NONE
