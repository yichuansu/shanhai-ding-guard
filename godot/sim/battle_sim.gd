class_name BattleSim
extends RefCounted
## 守鼎战的权威模拟。固定 10Hz tick，只依赖 core/、content/defs 与 sim/ 下的类，
## 不引用 Node、渲染、输入或任何 SDK，所以能在无头测试和平衡工具里直接跑。
##
## 表现层只读公开字段，并通过 queue_* 提交意图；意图在下一拍开头生效。
##
## 每拍顺序：
##   1. tick+1，清空 events，应用意图（部署 / 收回 / 捕获）
##   2. 自然回灵气
##   3. 出怪
##   4. 敌人沿路径移动；到终点记漏怪，扣鼎耐久
##   5. 持续伤害（灼烧）
##   6. 飞弹移动；命中拍结算伤害与 on_hit 特效
##   7. 塔冷却与开火（跳过已被在途伤害预定致死的敌人）
##   8. 清理死亡单位，结算清波（on_wave_end），判定胜负
##
## 支持的效果（EffectDef.trigger / op）：
##   passive         / adjacent_damage_pct  相邻异兽伤害 +amount
##   passive         / global_damage_pct    全体伤害 +amount（法宝）
##   on_battle_start / add_talismans        本场额外 amount 张镇鼎符，不消耗局内库存
##   on_hit          / slow                 移速 ×amount，持续 duration_ticks
##   on_hit          / burn                 每拍 amount 点伤害，持续 duration_ticks
##   on_kill_nearby  / bonus_shells         radius 内有敌人被击杀时额外 amount 贝币
##   on_wave_end     / heal_ding            每清一波回复 amount 鼎耐久

enum Outcome { RUNNING, WON, LOST }

const TICKS_PER_SECOND := 10.0
const TIER_DAMAGE_MULT: Array[float] = [1.0, 1.0, 1.6, 2.5]
const RECALL_REFUND_RATIO := 0.5
const CAPTURE_LIMIT_PER_BATTLE := 3
const PROJECTILE_ORIGIN_OFFSET := Vector2(0, -30)

var error := ""
var battle: BattleDef
var path: PathCurve
var tick := 0
var outcome: Outcome = Outcome.RUNNING
var spirit := 0
var ding_hp := 0
var ding_max := 0
var talismans := 0
var talismans_used := 0
var bonus_talismans := 0
var shells_earned := 0
var roster: Array[BeastInstance] = []
var enemies: Array[EnemyUnit] = []
## slot(int) -> TowerUnit
var towers: Dictionary = {}
var projectiles: Array[Projectile] = []
var captured_beasts: Array[StringName] = []
## 本拍发生的事，给表现层播特效和音效。每拍开头清空。
var events: Array[Dictionary] = []

var _beasts: Dictionary = {}
var _chart: ElementChart
var _relics: Array[RelicDef] = []
var _rng: RngStream
var _waves: WaveDirector
var _intents: Array[Dictionary] = []
var _next_id := 1
var _resolved_per_wave := PackedInt32Array()
var _wave_cleared: Array[bool] = []
## trigger(StringName) -> Array[{tower: TowerUnit|null, effect: EffectDef}]
var _effects: Dictionary = {}
var _global_damage_bonus := 0.0
var _started := false


static func create(def: BattleDef, beasts: Dictionary, chart: ElementChart, setup: BattleSetup) -> BattleSim:
	var sim := BattleSim.new()
	sim.error = _validate(def, beasts, setup)
	if sim.error != "":
		return sim
	sim.battle = def
	sim.path = PathCurve.new(def.path_points)
	sim._beasts = beasts
	sim._chart = chart
	sim.roster = setup.roster.duplicate()
	sim._relics = setup.relics.duplicate()
	sim.ding_hp = setup.ding_hp
	sim.ding_max = setup.ding_max
	sim.talismans = setup.talismans
	sim.spirit = def.starting_spirit
	sim._rng = RngStream.new(setup.seed_value)
	sim._waves = WaveDirector.new(def.waves)
	sim._resolved_per_wave.resize(def.waves.size())
	for i in def.waves.size():
		sim._wave_cleared.append(false)
	sim._rebuild_effects()
	return sim


static func _validate(def: BattleDef, beasts: Dictionary, setup: BattleSetup) -> String:
	if def == null:
		return "没有战场数据"
	if def.path_points.size() < 2:
		return "%s 路径点少于 2 个" % def.id
	if def.waves.is_empty():
		return "%s 没有波次" % def.id
	for wave in def.waves:
		for spawn in wave.spawns:
			if not beasts.has(spawn.beast_id):
				return "%s 引用了不存在的异兽 %s" % [def.id, spawn.beast_id]
	for inst in setup.roster:
		if not beasts.has(inst.beast_id):
			return "阵容里有不存在的异兽 %s" % inst.beast_id
	return ""


# ---------- 意图（表现层调用） ----------

func begin() -> void:
	if _started or error != "":
		return
	_started = true
	for entry: Dictionary in _effects.get(&"on_battle_start", []):
		var eff: EffectDef = entry.effect
		if eff.op == &"add_talismans":
			talismans += int(eff.amount)
			bonus_talismans += int(eff.amount)


func queue_deploy(uid: int, slot: int) -> void:
	_intents.append({"kind": "deploy", "uid": uid, "slot": slot})


func queue_recall(slot: int) -> void:
	_intents.append({"kind": "recall", "slot": slot})


func queue_capture(enemy_id: int) -> void:
	_intents.append({"kind": "capture", "enemy_id": enemy_id})


# ---------- 查询 ----------

func is_running() -> bool:
	return _started and outcome == Outcome.RUNNING


func instance_by_uid(uid: int) -> BeastInstance:
	for inst in roster:
		if inst.uid == uid:
			return inst
	return null


func is_deployed(uid: int) -> bool:
	for t: TowerUnit in towers.values():
		if t.instance.uid == uid:
			return true
	return false


func deploy_cost(uid: int) -> int:
	var inst := instance_by_uid(uid)
	return 0 if inst == null else (_beasts[inst.beast_id] as BeastDef).deploy_cost


func beast_def(beast_id: StringName) -> BeastDef:
	return _beasts.get(beast_id)


func first_free_slot() -> int:
	for i in battle.slots.size():
		if not towers.has(i):
			return i
	return -1


func enemy_by_id(id: int) -> EnemyUnit:
	for e in enemies:
		if e.id == id:
			return e
	return null


func enemy_position(e: EnemyUnit) -> Vector2:
	return path.position_at(e.distance)


func wave_count() -> int:
	return battle.waves.size()


## 从 1 起，供 HUD 显示。
func current_wave_number() -> int:
	return mini(_waves.wave_index + 1, wave_count())


## 一局库存实际消耗的镇鼎符（法宝给的临时符不算）。
func run_talismans_spent() -> int:
	return maxi(talismans_used - bonus_talismans, 0)


func damage_against(t: TowerUnit, e: EnemyUnit) -> float:
	var base := t.def.damage * TIER_DAMAGE_MULT[clampi(t.instance.tier, 1, BeastInstance.MAX_TIER)]
	return base * _chart.multiplier(t.def.element, e.def.element) * (1.0 + t.damage_bonus + _global_damage_bonus)


# ---------- 推进 ----------

func step() -> void:
	if not is_running():
		return
	tick += 1
	events.clear()
	_apply_intents()
	if battle.spirit_income_interval_ticks > 0 and tick % battle.spirit_income_interval_ticks == 0:
		spirit += 1
	_spawn()
	_move_enemies()
	_tick_statuses()
	_move_projectiles()
	_towers_fire()
	_cleanup()
	_check_wave_clears()
	_check_outcome()


func _apply_intents() -> void:
	var pending := _intents
	_intents = []
	for intent in pending:
		match intent["kind"]:
			"deploy":
				_try_deploy(intent["uid"], intent["slot"])
			"recall":
				_try_recall(intent["slot"])
			"capture":
				_try_capture(intent["enemy_id"])


func _try_deploy(uid: int, slot: int) -> void:
	if slot < 0 or slot >= battle.slots.size() or towers.has(slot):
		return
	var inst := instance_by_uid(uid)
	if inst == null or is_deployed(uid):
		return
	var def: BeastDef = _beasts[inst.beast_id]
	if spirit < def.deploy_cost:
		return
	spirit -= def.deploy_cost
	var t := TowerUnit.new()
	t.slot = slot
	t.instance = inst
	t.def = def
	t.position = battle.slots[slot]
	towers[slot] = t
	_rebuild_effects()
	events.append({"type": "deployed", "slot": slot, "uid": uid})


func _try_recall(slot: int) -> void:
	if not towers.has(slot):
		return
	var t: TowerUnit = towers[slot]
	spirit += floori(t.def.deploy_cost * RECALL_REFUND_RATIO)
	towers.erase(slot)
	_rebuild_effects()
	events.append({"type": "recalled", "slot": slot, "uid": t.instance.uid})


func _try_capture(enemy_id: int) -> void:
	var e := enemy_by_id(enemy_id)
	if e == null or not e.is_capturable() or talismans <= 0:
		return
	talismans -= 1
	talismans_used += 1
	e.alive = false
	e.captured = true
	captured_beasts.append(e.def.id)
	_resolve(e)
	events.append({"type": "captured", "enemy_id": e.id, "beast_id": e.def.id, "position": enemy_position(e)})


func _spawn() -> void:
	for req in _waves.step():
		var def: BeastDef = _beasts[req["beast_id"]]
		var e := EnemyUnit.new()
		e.id = _next_id
		_next_id += 1
		e.def = def
		e.wave_index = req["wave_index"]
		e.max_hp = maxi(1, roundi(def.max_hp * float(req["hp_multiplier"])))
		e.hp = e.max_hp
		enemies.append(e)
		events.append({"type": "spawned", "enemy_id": e.id})


func _move_enemies() -> void:
	for e in enemies:
		if not e.alive:
			continue
		e.prev_distance = e.distance
		var speed := e.def.move_speed / TICKS_PER_SECOND
		if e.slow_ticks > 0:
			speed *= e.slow_multiplier
			e.slow_ticks -= 1
		e.distance += speed
		if e.distance >= path.length:
			e.distance = path.length
			e.alive = false
			e.leaked = true
			ding_hp -= e.def.leak_damage
			_resolve(e)
			events.append({"type": "leaked", "enemy_id": e.id, "damage": e.def.leak_damage})


func _tick_statuses() -> void:
	for e in enemies:
		if not e.alive or e.burn_ticks <= 0:
			continue
		e.hp -= e.burn_per_tick
		e.burn_ticks -= 1
		if e.hp <= 0.0:
			_kill(e)


func _move_projectiles() -> void:
	for p in projectiles:
		if p.done:
			continue
		p.prev_position = p.position
		var target := enemy_by_id(p.target_id)
		var chasing := target != null and target.alive
		if chasing:
			p.aim = enemy_position(target)
		var to := p.aim - p.position
		var dist := to.length()
		if dist > p.speed:
			p.position += to / dist * p.speed
			continue
		p.position = p.aim
		p.done = true
		if target != null:
			target.reserved_damage -= p.damage
		if chasing:
			_hit(target, p)
		else:
			events.append({"type": "dissipated", "projectile_id": p.id})


func _hit(e: EnemyUnit, p: Projectile) -> void:
	e.hp -= p.damage
	events.append({"type": "hit", "enemy_id": e.id, "position": p.position, "damage": p.damage})
	for eff in p.on_hit:
		match eff.op:
			&"slow":
				e.slow_multiplier = eff.amount if e.slow_ticks <= 0 else minf(e.slow_multiplier, eff.amount)
				e.slow_ticks = maxi(e.slow_ticks, eff.duration_ticks)
			&"burn":
				e.burn_per_tick = eff.amount if e.burn_ticks <= 0 else maxf(e.burn_per_tick, eff.amount)
				e.burn_ticks = maxi(e.burn_ticks, eff.duration_ticks)
	if e.hp <= 0.0:
		_kill(e)


func _kill(e: EnemyUnit) -> void:
	if not e.alive:
		return
	e.alive = false
	spirit += e.def.spirit_reward
	shells_earned += e.def.shell_reward
	_resolve(e)
	var pos := enemy_position(e)
	events.append({"type": "killed", "enemy_id": e.id, "position": pos})
	for entry: Dictionary in _effects.get(&"on_kill_nearby", []):
		var eff: EffectDef = entry.effect
		var t: TowerUnit = entry.tower
		if eff.op == &"bonus_shells" and t != null and t.position.distance_to(pos) <= eff.radius:
			shells_earned += int(eff.amount)
			events.append({"type": "bonus_shells", "slot": t.slot, "amount": int(eff.amount)})


func _towers_fire() -> void:
	var slots := towers.keys()
	slots.sort()
	for s: int in slots:
		var t: TowerUnit = towers[s]
		if t.cooldown > 0:
			t.cooldown -= 1
		if t.cooldown > 0:
			continue
		var target := _pick_target(t)
		if target == null:
			continue
		var p := Projectile.new()
		p.id = _next_id
		_next_id += 1
		p.slot = s
		p.target_id = target.id
		p.position = t.position + PROJECTILE_ORIGIN_OFFSET
		p.prev_position = p.position
		p.aim = enemy_position(target)
		p.speed = t.def.projectile_speed / TICKS_PER_SECOND
		p.damage = damage_against(t, target)
		p.element = t.def.element
		for eff in t.def.traits:
			if eff.trigger == &"on_hit":
				p.on_hit.append(eff)
		target.reserved_damage += p.damage
		projectiles.append(p)
		t.cooldown = t.def.attack_interval_ticks
		events.append({"type": "fired", "slot": s, "projectile_id": p.id})


## 射程内、没被预定致死、沿路径走得最远的敌人。
func _pick_target(t: TowerUnit) -> EnemyUnit:
	var best: EnemyUnit = null
	for e in enemies:
		if not e.alive or e.hp - e.reserved_damage <= 0.0:
			continue
		if t.position.distance_to(enemy_position(e)) > t.def.attack_range:
			continue
		if best == null or e.distance > best.distance:
			best = e
	return best


func _cleanup() -> void:
	var alive_enemies: Array[EnemyUnit] = []
	for e in enemies:
		if e.alive:
			alive_enemies.append(e)
	enemies = alive_enemies
	var flying: Array[Projectile] = []
	for p in projectiles:
		if not p.done:
			flying.append(p)
	projectiles = flying


func _resolve(e: EnemyUnit) -> void:
	_resolved_per_wave[e.wave_index] += 1


func _check_wave_clears() -> void:
	for w in _wave_cleared.size():
		if _wave_cleared[w] or not _waves.wave_fully_spawned(w):
			continue
		if _resolved_per_wave[w] < _waves.total_per_wave[w]:
			continue
		_wave_cleared[w] = true
		events.append({"type": "wave_cleared", "wave_index": w})
		for entry: Dictionary in _effects.get(&"on_wave_end", []):
			var eff: EffectDef = entry.effect
			if eff.op == &"heal_ding":
				ding_hp = mini(ding_max, ding_hp + int(eff.amount))


func _check_outcome() -> void:
	if ding_hp <= 0:
		outcome = Outcome.LOST
	elif _waves.finished_spawning and enemies.is_empty():
		outcome = Outcome.WON
	else:
		return
	for p in projectiles:
		events.append({"type": "dissipated", "projectile_id": p.id})
	projectiles.clear()
	events.append({"type": "outcome", "won": outcome == Outcome.WON})


func _rebuild_effects() -> void:
	_effects.clear()
	_global_damage_bonus = 0.0
	for relic in _relics:
		for eff in relic.effects:
			_register(null, eff)
	var slots := towers.keys()
	slots.sort()
	for s: int in slots:
		var t: TowerUnit = towers[s]
		for eff in t.def.traits:
			_register(t, eff)
	for entry: Dictionary in _effects.get(&"passive", []):
		var eff: EffectDef = entry.effect
		if eff.op == &"global_damage_pct":
			_global_damage_bonus += eff.amount
	_recompute_bonuses()


func _register(t: TowerUnit, eff: EffectDef) -> void:
	if not _effects.has(eff.trigger):
		_effects[eff.trigger] = []
	_effects[eff.trigger].append({"tower": t, "effect": eff})


func _recompute_bonuses() -> void:
	for t: TowerUnit in towers.values():
		var bonus := 0.0
		for o: TowerUnit in towers.values():
			if o == t or o.position.distance_to(t.position) > battle.adjacency_radius:
				continue
			if Elements.generates(o.def.element, t.def.element):
				bonus += _chart.generate_bonus
			for eff in o.def.traits:
				if eff.trigger == &"passive" and eff.op == &"adjacent_damage_pct":
					bonus += eff.amount
		t.damage_bonus = bonus
