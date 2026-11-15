class_name AutoPlayer
extends RefCounted
## 无头测试和平衡模拟用的简单策略：灵气够就按阵容顺序部署到空鼎位，能捕获就捕获。

var capture_enabled := true
var deploy_enabled := true
var skill_enabled := true


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
	if not deploy_enabled:
		return
	for inst in sim.roster:
		if sim.is_deployed(inst.uid):
			continue
		var slot := sim.first_free_slot()
		if slot >= 0 and sim.spirit >= sim.deploy_cost(inst.uid):
			sim.queue_deploy(inst.uid, slot)
		break


func play(sim: BattleSim, max_ticks: int = 20000) -> void:
	sim.begin()
	while sim.is_running() and sim.tick < max_ticks:
		act(sim)
		sim.step()
