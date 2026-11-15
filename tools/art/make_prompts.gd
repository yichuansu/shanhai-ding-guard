extends SceneTree
## 根据内容数据生成每只异兽的 AI 绘图提示词，写到 art_src/PROMPTS.md。
##   godot --headless --path . --script res://tools/art/make_prompts.gd
## 外观描述按《山海经》原文写成英文（主流绘图模型对英文理解最好），风格、配色、构图要求统一拼接。

const STYLE := "Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only"
const FRAMING := "single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature"
const NEGATIVE := "text, letters, calligraphy, seal stamp, border, frame, multiple creatures, human, cropped, photorealistic, 3d render, gradient background, glossy, anime, chibi, watermark"

const COLOR_WORDS := {
	&"mu": "muted pine green (#2f7d5a) with deep green and pale green accents",
	&"huo": "cinnabar red (#b9402c) with dark red and salmon accents",
	&"tu": "ochre yellow (#b8892e) with dark ochre and pale sand accents",
	&"jin": "pale silver white (#c9d0d4) with grey accents",
	&"shui": "indigo black-blue (#26384d) with slate blue accents",
}

## 外观描述（依据原文）。
const LOOKS := {
	&"dangkang": "a wild boar-like beast with long curved tusks, stocky body, bristly back, calling out its own name",
	&"lili": "a pig-like beast with sharp spurs on its legs like a rooster, digging the earth, barking like a dog",
	&"fuzhu": "a white deer with four antlers, slender legs, calm watchful pose",
	&"bifang": "a crane-like bird standing on a single leg, red patterns on a dark blue-green body, white beak, sparks of fire around it",
	&"huashe": "a creature with a human face and a jackal body, bird wings on its back, moving like a snake, water splashing",
	&"wenyao": "a carp-like fish with bird wings, dark patterns, white head and red beak, leaping through the air",
	&"jingwei": "a small crow-like bird with a patterned head, white beak and red feet, carrying a twig in its beak",
	&"mingshe": "a snake with four feathered wings, coiled body, mouth open as if ringing like a stone chime",
	&"zhuyan": "an ape-like beast with a white head and red feet, aggressive war stance",
	&"xiangliu": "a giant serpent with nine human-like heads on long necks, coiled body, menacing",
	&"lingling": "an ox-like beast with tiger stripes, lowing, sturdy stance",
	&"zhuru": "a fox-like beast with fish fins instead of wings, crouching nervously",
	&"bibi": "a fox-like beast with bird wings, honking like a wild goose, dry cracked ground beneath",
	&"lihu": "a mandarin-duck-like bird with human feet, waddling",
	&"jiegou": "a wild-duck-like bird with a long rat tail, climbing a tree branch",
	&"heyu": "a boar-like beast with a human face, yellow body and red tail",
	&"youyou": "a horse-like beast with goat eyes, four horns and an ox tail, howling",
	&"longzhi": "a fox-like beast with nine tails, nine heads and tiger claws",
	&"fei": "an ox-like beast with a white head, a single eye and a snake tail, withered grass around its hooves",
	&"fenghuang": "a phoenix shaped like a rooster with five-colored patterned plumage, long flowing tail feathers, dancing",
	&"yinglong": "a winged dragon with large feathered wings, summoning rain clouds",
	&"bo": "a white horse with a black tail and a single horn, tiger fangs and claws",
	&"kui": "a one-legged ox with a dark grey-green hornless body, glowing like the sun and moon, thunder around it",
	&"goumang": "a deity with a bird body and a human face, riding two small dragons, spring leaves around",
	&"tianwu": "a water deity with eight human heads, a tiger body, eight legs and eight tails, blue-yellow coloring",
	&"dingsha_tu": "a small swirling wisp of earthy smoke with two hollow eyes, shaped like a crack escaping a bronze cauldron",
	&"dingsha_shui": "a small swirling wisp of watery mist with two hollow eyes, shaped like a crack escaping a bronze cauldron",
	&"dingsha_huo": "a small swirling wisp of fiery smoke with two hollow eyes, shaped like a crack escaping a bronze cauldron",
	&"dingsha_mu": "a small swirling wisp of leafy green smoke with two hollow eyes, shaped like a crack escaping a bronze cauldron",
	&"dingsha_jin": "a small swirling wisp of metallic grey smoke with two hollow eyes, shaped like a crack escaping a bronze cauldron",
}


func _initialize() -> void:
	var lib := ContentLibrary.load_from()
	var lines := PackedStringArray([
		"# 异兽绘图提示词",
		"",
		"由 `tools/art/make_prompts.gd` 根据内容数据生成，不要手改；要调整外观描述，改脚本里的 LOOKS 再重新生成。",
		"用法见 `docs/ART_PIPELINE.md`。每只异兽：提示词 → 生成 → 挑一张存为 `art_src/beasts/<id>/raw.png` → 运行 `prepare_beast.py`。",
		"",
		"通用负面提示词（支持的工具里填到 negative prompt）：",
		"",
		"```",
		NEGATIVE,
		"```",
		"",
	])
	var missing := PackedStringArray()
	var ids: Array[StringName] = []
	for s in Bestiary.sections():
		ids.append_array(Bestiary.section_ids(lib, s["id"]))
	for id: StringName in lib.beasts:
		if not ids.has(id):
			ids.append(id)
	for id in ids:
		var def: BeastDef = lib.beasts[id]
		if not LOOKS.has(id):
			missing.append(String(id))
			continue
		var prompt := "%s, %s, %s, colors: %s and black ink" % [LOOKS[id], STYLE, FRAMING, COLOR_WORDS[def.element]]
		lines.append("## %s %s（%s）" % [def.display_name, def.name_en, Elements.DISPLAY[def.element]])
		lines.append("")
		if def.lore != "":
			lines.append("原文：%s" % def.lore)
			lines.append("")
		lines.append("保存为：`art_src/beasts/%s/raw.png`%s" % [id, "　状态：已有美术" if BeastArt.has_art(id) else ""])
		lines.append("")
		lines.append("```")
		lines.append(prompt)
		lines.append("```")
		lines.append("")
	var f := FileAccess.open("res://art_src/PROMPTS.md", FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("已生成 %d 只异兽的提示词 → art_src/PROMPTS.md" % (ids.size() - missing.size()))
	if not missing.is_empty():
		push_error("缺少外观描述：" + ", ".join(missing))
	quit(1 if not missing.is_empty() else 0)
