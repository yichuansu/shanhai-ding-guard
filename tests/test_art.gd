extends TestCase
## 美术接入：按命名约定找图，没有就退回灰盒；提示词覆盖所有异兽。

var lib := ContentLibrary.load_from()


func test_missing_art_falls_back() -> void:
	check(BeastArt.beast_texture(&"no_such_beast") == null, "没有图返回 null")
	check(not BeastArt.has_art(&"no_such_beast"), "没有图时 has_art 为假")
	check(BeastArt.prop_texture("no_such_prop") == null, "没有道具图返回 null")


func test_display_heights_cover_all_rarities() -> void:
	for r in BeastDef.Rarity.values():
		check(BeastArt.HEIGHT_BY_RARITY.has(r), "稀有度 %d 有显示高度" % r)
	check(BeastArt.HEIGHT_BY_RARITY[BeastDef.Rarity.BOSS] > BeastArt.HEIGHT_BY_RARITY[BeastDef.Rarity.COMMON], "首领比普通异兽大")


func test_every_beast_has_prompt_look() -> void:
	var script: GDScript = load("res://tools/art/make_prompts.gd")
	var looks: Dictionary = script.get_script_constant_map()["LOOKS"]
	var colors: Dictionary = script.get_script_constant_map()["COLOR_WORDS"]
	for id: StringName in lib.beasts:
		check(looks.has(id), "%s 有外观描述" % id)
	for e in Elements.ALL:
		check(colors.has(e), "%s 有配色描述" % e)


func test_beast_sprite_lifecycle() -> void:
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var s := BeastSprite.new()
	s.setup(ImageTexture.create_from_image(img), 110.0)
	s.attack(Vector2.LEFT)
	check_eq(s.facing, -1.0, "朝攻击方向转身")
	s.die()
	for i in 40:
		s._process(0.02)
	check(not s.visible, "死亡动作结束后隐藏")
	s.reset()
	check(s.visible and s.modulate.a == 1.0, "回收再用时复原")
	s.free()
