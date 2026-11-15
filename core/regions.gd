class_name Regions
extends RefCounted
## 九州里已经做了的州，按一局里的先后顺序排列。一局依次打完这些州的首领即通关。

const ORDER: Array[StringName] = [&"jizhou", &"qingzhou"]
const DISPLAY := {
	&"jizhou": "冀州",
	&"qingzhou": "青州",
}


static func display(region: StringName) -> String:
	return DISPLAY.get(region, String(region))


static func for_act(act: int) -> StringName:
	return ORDER[clampi(act, 0, ORDER.size() - 1)]


static func is_last_act(act: int) -> bool:
	return act >= ORDER.size() - 1
