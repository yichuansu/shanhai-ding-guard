extends SceneTree
## 无头平衡工具：每张战场 × 每种双异兽阵容，用 AutoPlayer 打一遍，输出胜率和平均剩余鼎耐久。
##   godot --headless --path godot --script res://tools/simulate_battles.gd
## 用来发现"某张图谁都过不了"或"某只异兽一只就够了"这类问题。

const DING := 10


func _initialize() -> void:
	var lib := ContentLibrary.load_from()
	for e in lib.errors:
		push_error(e)
	var towers: Array[StringName] = []
	var ids := lib.beasts.keys()
	ids.sort()
	for id: StringName in ids:
		var b: BeastDef = lib.beasts[id]
		if b.capturable:
			towers.append(id)
	var battle_ids := lib.battles.keys()
	battle_ids.sort()
	print("战场\t阵容数\t胜率\t平均剩余鼎\t平均时长(秒)")
	var per_beast := {}
	for bid: StringName in battle_ids:
		var battle: BattleDef = lib.battles[bid]
		var wins := 0
		var runs := 0
		var ding_left := 0
		var ticks := 0
		for i in towers.size():
			for j in range(i, towers.size()):
				var setup := BattleSetup.new()
				setup.roster = [BeastInstance.make(1, towers[i]), BeastInstance.make(2, towers[j])]
				setup.ding_hp = DING
				setup.ding_max = DING
				setup.talismans = 0
				var sim := BattleSim.create(battle, lib.beasts, lib.chart, setup)
				var ap := AutoPlayer.new()
				ap.capture_enabled = false
				ap.play(sim)
				runs += 1
				ticks += sim.tick
				if sim.outcome == BattleSim.Outcome.WON:
					wins += 1
					ding_left += sim.ding_hp
					for id in [towers[i], towers[j]]:
						per_beast[id] = int(per_beast.get(id, 0)) + 1
		print("%s\t%d\t%.0f%%\t%.1f\t%.0f" % [bid, runs, 100.0 * wins / runs, float(ding_left) / maxi(wins, 1), ticks / 10.0 / runs])
	print("\n异兽参与获胜次数（越高越强）：")
	for id: StringName in towers:
		print("  %s\t%d" % [id, int(per_beast.get(id, 0))])
	quit()
