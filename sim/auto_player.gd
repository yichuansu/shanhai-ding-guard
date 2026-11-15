class_name AutoPlayer
extends RefCounted
## 无头测试和平衡模拟用的简单策略，尽量接近一个"会玩但不精"的玩家：
## 能捕获就捕获；技能好了就砸最前面的敌人；按阵容顺序部署；部署完了就升级最便宜的；
## 场上没敌人时提前召唤下一波。

var capture_enabled := true
var deploy_enabled := true
var skill_enabled := true
var upgrade_enabled := true
var call_enabled := true


func act(sim: BattleSim) -> void:
	if capture_enabled and sim.talismans > 0:
		for e in sim.enemies:
			if sim.can_capture(e):
				sim.queue_capture(e.id)
				break
	if skill_enabled and sim.skill_ready() and not sim.enemies.is_empty():
		var lead := sim.enemies[0]
		for e in sim.enemies:
			if e.distance > lead.distance:
				lead = e
		sim.queue_skill(sim.enemy_position(lead))
	if call_enabled and sim.enemies.is_empty() and sim.wave_gap_remaining() > 0 and sim.tick > 1:
		sim.queue_call_wave()
	if not deploy_enabled:
		return
	for inst in sim.roster:
		if sim.is_deployed(inst.uid):
			continue
		var slot := sim.first_free_slot()
		if slot >= 0:
			if sim.spirit >= sim.deploy_cost(inst.uid):
				sim.queue_deploy(inst.uid, slot)
			return
		break
	if not upgrade_enabled:
		return
	var best := -1
	var best_cost := 1 << 30
	var slots := sim.towers.keys()
	slots.sort()
	for s: int in slots:
		var c := sim.upgrade_cost(s)
		if c > 0 and c < best_cost:
			best = s
			best_cost = c
	if best >= 0 and sim.spirit >= best_cost:
		sim.queue_upgrade(best)


func play(sim: BattleSim, max_ticks: int = 20000) -> void:
	sim.begin()
	while sim.is_running() and sim.tick < max_ticks:
		act(sim)
		sim.step()
