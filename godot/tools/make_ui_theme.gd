extends SceneTree
## 生成全局界面主题 res://assets/ui_theme.tres（字体、字号、按钮配色）。改主题后重跑：
##   godot --headless --path godot --script res://tools/make_ui_theme.gd


func _initialize() -> void:
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansSC-Subset.ttf")
	theme.default_font_size = 24
	theme.set_color("font_color", "Button", Color("f5f1e8"))
	theme.set_color("font_disabled_color", "Button", Color("d7d2c6"))
	theme.set_color("font_color", "Label", Color("1c2421"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(6)
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		match state:
			"normal":
				box.bg_color = Color("5d6b63")
			"hover":
				box.bg_color = Color("2f7d6d")
			"pressed":
				box.bg_color = Color("1f5a4e")
			"disabled":
				box.bg_color = Color("b3ada1")
			"focus":
				box.draw_center = false
				box.border_color = Color("c9a25a")
				box.set_border_width_all(3)
		theme.set_stylebox(state, "Button", box)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.98, 0.96, 0.92, 0.96)
	panel.set_corner_radius_all(10)
	panel.set_border_width_all(2)
	panel.border_color = Color("9c6a27")
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 24
	panel.content_margin_bottom = 24
	theme.set_stylebox("panel", "PanelContainer", panel)
	var err := ResourceSaver.save(theme, "res://assets/ui_theme.tres")
	print("ui_theme.tres 已生成" if err == OK else "保存失败 %d" % err)
	quit()
