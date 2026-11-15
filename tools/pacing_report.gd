extends SceneTree
## 节奏报告：用 AutoPlayer 模拟一个"会玩但不精"的玩家，量化每场战斗的手感指标。
##   godot --headless --path . --script res://tools/pacing_report.gd
##
## 指标与目标（对照 Kingdom Rush、明日方舟等同类作品的节奏）：
##   时长            不提前召唤时普通战 120–180 秒（提前召唤会更短，那是给熟练玩家的奖励）
##   剩余灵气        结束时 ≤ 15（钱要花得出去）
##   花费间隔        平均每 ≤ 12 秒有一次花费（部署 / 升级 / 技能）
##   末次花费        出现在战斗后 25% 之内（后半场仍有决策）
##   每杀命中        普通杂兵 2–5 下
##   单次伤害        两位到三位数

## 模拟一局中段：守鼎人开局阵容 + 两只捕获来的异兽，敌人血量按第 4 层，首领按第 7 层。
const ROSTER_EXTRA: Array[StringName] = [&"huashe", &"mingshe"]
## 首领战按一局末段：6 只异兽。
const BOSS_EXTRA: Array[StringName] = [&"huashe", &"mingshe", &"zhuyan", &"fuzhu"]
const MID_RUN_SCALE := 1.0 + RunState.DIFFICULTY_PER_LAYER * 4
const BOSS_SCALE := 1.0 + RunState.DIFFICULTY_PER_LAYER * 7


func _initialize() -> void:
	var lib := ContentLibrary.load_from()
	var battle_ids := lib.battles.keys()
	battle_ids.sort()
	print("战场\t守鼎人\t结果\t时长s\t自然时长s\t鼎\t剩余灵气\t花费间隔s\t末次花费%\t每杀命中\t单次伤害\t暴击%\t空场%")
	for bid: StringName in battle_ids:
		for kid in lib.keeper_ids():
			_report(lib, lib.battles[bid], lib.keepers[kid])
	quit()


func _make(lib: ContentLibrary, battle: BattleDef, keeper: KeeperDef) -> BattleSim:
	var setup := BattleSetup.new()
	var uid := 1
	var ids: Array[StringName] = keeper.starting_beasts.duplicate()
	var extras := BOSS_EXTRA if battle.kind == BattleDef.Kind.BOSS else ROSTER_EXTRA
	for extra in extras:
		if not ids.has(extra):
			ids.append(extra)
	for id in ids:
		setup.roster.append(BeastInstance.make(uid, id))
		uid += 1
	setup.keeper = keeper
	setup.formations = lib.formation_list()
	setup.talismans = 0
	setup.seed_value = 7
	setup.hp_scale = BOSS_SCALE if battle.kind == BattleDef.Kind.BOSS else MID_RUN_SCALE
	setup.boss_hp_scale = 1.0 + RunState.DIFFICULTY_PER_ACT * Regions.ORDER.find(battle.region)
	return BattleSim.create(battle, lib.beasts, lib.chart, setup)


func _report(lib: ContentLibrary, battle: BattleDef, keeper: KeeperDef) -> void:
	var natural := _make(lib, battle, keeper)
	var slow := AutoPlayer.new()
	slow.capture_enabled = false
	slow.call_enabled = false
	slow.play(natural)
	var sim := _make(lib, battle, keeper)
	var ap := AutoPlayer.new()
	ap.capture_enabled = false
	sim.begin()
	var spends: Array[int] = []
	var hits := 0
	var crits := 0
	var kills := 0
	var damage := 0.0
	var empty_ticks := 0
	while sim.is_running() and sim.tick < 30000:
		var before := sim.spirit
		ap.act(sim)
		sim.step()
		if sim.enemies.is_empty():
			empty_ticks += 1
		for ev in sim.events:
			match ev["type"]:
				"hit":
					hits += 1
					damage += float(ev["damage"])
					if ev["crit"]:
						crits += 1
				"killed":
					kills += 1
				"deployed", "upgraded", "skill":
					spends.append(sim.tick)
	var gap := float(sim.tick) / maxi(spends.size(), 1) / 10.0
	var last_pct: float = 0.0 if spends.is_empty() else 100.0 * spends.back() / sim.tick
	print("%s\t%s\t%s\t%.0f\t%.0f\t%d\t%d\t%.1f\t%.0f\t%.1f\t%.0f\t%.0f\t%.0f" % [
		battle.id, keeper.display_name, "胜" if sim.outcome == BattleSim.Outcome.WON else "负",
		sim.tick / 10.0, natural.tick / 10.0, maxi(sim.ding_hp, 0), sim.spirit, gap, last_pct, float(hits) / maxi(kills, 1),
		damage / maxi(hits, 1), 100.0 * crits / maxi(hits, 1), 100.0 * empty_ticks / maxi(sim.tick, 1)])
