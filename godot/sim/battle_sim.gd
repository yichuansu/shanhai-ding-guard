class_name BattleSim
extends RefCounted
## 守鼎战的权威模拟。固定 10Hz tick，只依赖 core/、content/defs 与 sim/ 下的类，
## 不引用 Node、渲染、输入或任何 SDK，所以能在无头测试和平衡工具里直接跑。
##
## 表现层只读公开字段，并通过 queue_* 提交意图；意图在下一拍开头生效。
##
## 每拍顺序：
##   1. tick+1，清空 events，技能冷却 -1，应用意图（部署 / 升级 / 收回 / 捕获 / 技能 / 提前召唤）
##   2. 自然回灵气（含木阵等 spirit_income）
##   3. 出怪
##   4. 敌人移动：定身的不动；被镇守挡住的原地攻击镇守；经过镇守拦截点时被挡下；到终点记漏怪
##   5. 镇守被打垮 / 恢复
##   6. 持续伤害（灼烧）
##   7. 飞弹移动；命中拍结算伤害与 on_hit 特效
##   8. 塔冷却与开火（跳过已被在途伤害预定致死的敌人）
##   9. 清理死亡单位，结算清波（on_wave_end），判定胜负
##
## 效果来源：异兽特性、法宝、守鼎人被动、五行阵（作用域为该五行）。支持的 trigger / op：
##   passive         / adjacent_damage_pct      相邻异兽伤害 +amount
##   passive         / global_damage_pct        全体伤害 +amount
##   passive         / element_damage_pct       作用域内异兽伤害 +amount
##   passive         / bonus_vs_element         对 element_scope 五行的敌人伤害 +amount（只读异兽自身特性）
##   passive         / spirit_income            每 duration_ticks 拍额外 +amount 灵气
##   passive         / guard_hp_pct             作用域内（空 = 全部）镇守生命 +amount
##   passive         / capture_threshold_bonus  捕获血线 +amount
##   on_battle_start / add_talismans            本场额外 amount 张临时镇鼎符
##   on_hit          / slow                     移速 ×amount，持续 duration_ticks
##   on_hit          / burn                     每拍 amount 点伤害，持续 duration_ticks
##   on_hit          / splash                   radius 内其他敌人受到本次伤害 ×amount
##   on_hit          / ignite_nearby            radius 内最近的另一个敌人灼烧 amount，持续 duration_ticks
##   on_hit          / dry                      目标若被减速：额外造成本次伤害 ×amount，并解除减速
##   on_kill_nearby  / bonus_shells             radius 内有敌人被击杀时额外 amount 贝币
##   on_wave_end     / heal_ding                每清一波回复 amount 鼎耐久

enum Outcome { RUNNING, WON, LOST }

const TICKS_PER_SECOND := 10.0
const TIER_DAMAGE_MULT: Array[float] = [1.0, 1.0, 1.6, 2.5]
const TIER_GUARD_MULT: Array[float] = [1.0, 1.0, 1.5, 2.2]
const RECALL_REFUND_RATIO := 0.5
## 局内升级：索引是当前等级，值是升到下一级的费用倍率（相对部署费）。
const UPGRADE_COST_MULT: Array[float] = [0.0, 2.0, 3.5]
const MAX_LEVEL := 3
const LEVEL_DAMAGE_MULT: Array[float] = [1.0, 1.0, 1.6, 2.4]
const LEVEL_RANGE_MULT: Array[float] = [1.0, 1.0, 1.1, 1.2]
const LEVEL_GUARD_MULT: Array[float] = [1.0, 1.0, 1.5, 2.2]
## 提前召唤：倒计时每剩 1 秒奖励的灵气。
const EARLY_CALL_SPIRIT_PER_SECOND := 0.5
const CAPTURE_LIMIT_PER_BATTLE := 3
const PROJECTILE_ORIGIN_OFFSET := Vector2(0, -30)

var error := ""
var battle: BattleDef
var path: PathCurve
var keeper: KeeperDef
var tick := 0
var outcome: Outcome = Outcome.RUNNING
var spirit := 0
var ding_hp := 0
var ding_max := 0
var talismans := 0
var talismans_used := 0
var bonus_talismans := 0
var shells_earned := 0
var skill_cooldown := 0
var roster: Array[BeastInstance] = []
var enemies: Array[EnemyUnit] = []
## slot(int) -> TowerUnit
var towers: Dictionary = {}
var projectiles: Array[Projectile] = []
var captured_beasts: Array[StringName] = []
## element(StringName) -> 已生效的档位 count（HUD 显示用）
var active_formations: Dictionary = {}
## 本拍发生的事，给表现层播特效和音效。每拍开头清空。
var events: Array[Dictionary] = []

var _beasts: Dictionary = {}
var _chart: ElementChart
var _relics: Array[RelicDef] = []
var _formations: Array[FormationDef] = []
var _rng: RngStream
var _waves: WaveDirector
var _intents: Array[Dictionary] = []
var _next_id := 1
var _resolved_per_wave := PackedInt32Array()
var _wave_cleared: Array[bool] = []
## trigger(StringName) -> Array[{tower: TowerUnit|null, effect: EffectDef, scope: StringName}]
var _effects: Dictionary = {}
var _global_damage_bonus := 0.0
var _capture_bonus := 0.0
var _started := false
var _hp_scale := 1.0


static func create(def: BattleDef, beasts: Dictionary, chart: ElementChart, setup: BattleSetup) -> BattleSim:
	var sim := BattleSim.new()
	sim.error = _validate(def, beasts, setup)
	if sim.error != "":
		return sim
	sim.battle = def
	sim.path = PathCurve.new(def.path_points)
	sim.keeper = setup.keeper
	sim._beasts = beasts
	sim._chart = chart
	sim.roster = setup.roster.duplicate()
	sim._relics = setup.relics.duplicate()
	sim._formations = setup.formations.duplicate()
	sim.ding_hp = setup.ding_hp
	sim.ding_max = setup.ding_max
	sim.talismans = setup.talismans
	sim.spirit = def.starting_spirit
	sim._hp_scale = maxf(setup.hp_scale, 0.01)
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


func queue_skill(target: Vector2) -> void:
	_intents.append({"kind": "skill", "target": target})


func queue_upgrade(slot: int) -> void:
	_intents.append({"kind": "upgrade", "slot": slot})


func queue_call_wave() -> void:
	_intents.append({"kind": "call"})


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


func can_capture(e: EnemyUnit) -> bool:
	return e.is_capturable(_capture_bonus)


func skill_ready() -> bool:
	return keeper != null and keeper.skill != null and skill_cooldown == 0 and spirit >= keeper.skill.spirit_cost


## 升到下一级的费用；已满级或没有异兽返回 -1。
func upgrade_cost(slot: int) -> int:
	var t: TowerUnit = towers.get(slot)
	if t == null or t.level >= MAX_LEVEL:
		return -1
	return ceili(t.def.deploy_cost * UPGRADE_COST_MULT[t.level])


func recall_refund(slot: int) -> int:
	var t: TowerUnit = towers.get(slot)
	return 0 if t == null else floori(t.invested * RECALL_REFUND_RATIO)


func tower_range(t: TowerUnit) -> float:
	return t.def.attack_range * LEVEL_RANGE_MULT[clampi(t.level, 1, MAX_LEVEL)]


## 波前倒计时剩余拍数，0 表示不在倒计时中。
func wave_gap_remaining() -> int:
	return _waves.gap_remaining()


func early_call_bonus() -> int:
	return ceili(wave_gap_remaining() / TICKS_PER_SECOND * EARLY_CALL_SPIRIT_PER_SECOND)


## 即将到来的那一波：beast_id -> 数量。全部出完返回空。
func next_wave_preview() -> Dictionary:
	return {} if _waves.finished_spawning else _waves.preview(_waves.wave_index)


func wave_count() -> int:
	return battle.waves.size()


## 从 1 起，供 HUD 显示。
func current_wave_number() -> int:
	return mini(_waves.wave_index + 1, wave_count())


## 一局库存实际消耗的镇鼎符（法宝和守鼎人给的临时符不算）。
func run_talismans_spent() -> int:
	return maxi(talismans_used - bonus_talismans, 0)


func damage_against(t: TowerUnit, e: EnemyUnit) -> float:
	var base := t.def.damage * TIER_DAMAGE_MULT[clampi(t.instance.tier, 1, BeastInstance.MAX_TIER)] * LEVEL_DAMAGE_MULT[clampi(t.level, 1, MAX_LEVEL)]
	var bonus := t.damage_bonus + _global_damage_bonus
	for eff in t.def.traits:
		if eff.trigger == &"passive" and eff.op == &"bonus_vs_element" and eff.element_scope == e.def.element:
			bonus += eff.amount
	return base * _chart.multiplier(t.def.element, e.def.element) * (1.0 + bonus)


# ---------- 推进 ----------

func step() -> void:
	if not is_running():
		return
	tick += 1
	events.clear()
	if skill_cooldown > 0:
		skill_cooldown -= 1
	_apply_intents()
	_income()
	_spawn()
	_move_enemies()
	_update_guards()
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
			"skill":
				_try_skill(intent["target"])
			"upgrade":
				_try_upgrade(intent["slot"])
			"call":
				_try_call_wave()


func _income() -> void:
	if battle.spirit_income_interval_ticks > 0 and tick % battle.spirit_income_interval_ticks == 0:
		spirit += 1
	for entry: Dictionary in _effects.get(&"passive", []):
		var eff: EffectDef = entry.effect
		if eff.op == &"spirit_income" and eff.duration_ticks > 0 and tick % eff.duration_ticks == 0:
			spirit += int(eff.amount)


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
	t.invested = def.deploy_cost
	if def.guard_hp > 0:
		t.is_guard = true
		var c := path.closest(t.position)
		t.guard_active = c.y <= def.guard_reach
		t.block_distance = c.x
	towers[slot] = t
	_rebuild_effects()
	if t.is_guard:
		t.guard_hp = t.guard_hp_max
	events.append({"type": "deployed", "slot": slot, "uid": uid})


func _try_recall(slot: int) -> void:
	if not towers.has(slot):
		return
	var t: TowerUnit = towers[slot]
	_release_blocked(t)
	spirit += recall_refund(slot)
	towers.erase(slot)
	_rebuild_effects()
	events.append({"type": "recalled", "slot": slot, "uid": t.instance.uid})


func _try_upgrade(slot: int) -> void:
	var cost := upgrade_cost(slot)
	if cost < 0 or spirit < cost:
		return
	var t: TowerUnit = towers[slot]
	spirit -= cost
	t.invested += cost
	t.level += 1
	_recompute_bonuses()
	if t.is_guard and t.guard_down_ticks == 0:
		t.guard_hp = t.guard_hp_max
	events.append({"type": "upgraded", "slot": slot, "level": t.level})


func _try_call_wave() -> void:
	var bonus := early_call_bonus()
	if _waves.call_early() <= 0:
		return
	spirit += bonus
	events.append({"type": "wave_called", "bonus": bonus})


func _try_capture(enemy_id: int) -> void:
	var e := enemy_by_id(enemy_id)
	if e == null or not can_capture(e) or talismans <= 0:
		return
	talismans -= 1
	talismans_used += 1
	e.alive = false
	e.captured = true
	captured_beasts.append(e.def.id)
	_resolve(e)
	events.append({"type": "captured", "enemy_id": e.id, "beast_id": e.def.id, "position": enemy_position(e)})


func _try_skill(target: Vector2) -> void:
	if not skill_ready():
		return
	var skill := keeper.skill
	spirit -= skill.spirit_cost
	skill_cooldown = skill.cooldown_ticks
	match skill.op:
		&"damage_area":
			for e in enemies:
				if e.alive and enemy_position(e).distance_to(target) <= skill.radius:
					_damage_enemy(e, skill.amount)
		&"freeze_area":
			for e in enemies:
				if e.alive and enemy_position(e).distance_to(target) <= skill.radius:
					e.frozen_ticks = maxi(e.frozen_ticks, skill.duration_ticks)
		&"smite_strongest":
			var strongest: EnemyUnit = null
			for e in enemies:
				if e.alive and (strongest == null or e.hp > strongest.hp):
					strongest = e
			if strongest != null:
				target = enemy_position(strongest)
				_damage_enemy(strongest, skill.amount)
	events.append({"type": "skill", "op": skill.op, "position": target, "radius": skill.radius})


func _spawn() -> void:
	for req in _waves.step():
		var def: BeastDef = _beasts[req["beast_id"]]
		var e := EnemyUnit.new()
		e.id = _next_id
		_next_id += 1
		e.def = def
		e.wave_index = req["wave_index"]
		e.max_hp = maxi(1, roundi(def.max_hp * float(req["hp_multiplier"]) * _hp_scale))
		e.hp = e.max_hp
		enemies.append(e)
		events.append({"type": "spawned", "enemy_id": e.id})


func _move_enemies() -> void:
	var guards := _guards_by_distance()
	for e in enemies:
		if not e.alive:
			continue
		e.prev_distance = e.distance
		if e.frozen_ticks > 0:
			e.frozen_ticks -= 1
			continue
		if e.blocked_by >= 0:
			var holder: TowerUnit = towers.get(e.blocked_by)
			if holder != null and holder.guard_ready():
				holder.guard_hp -= e.def.contact_damage
				continue
			e.blocked_by = -1
		var speed := e.def.move_speed / TICKS_PER_SECOND
		if e.slow_ticks > 0:
			speed *= e.slow_multiplier
			e.slow_ticks -= 1
		var next_distance := e.distance + speed
		if e.def.rarity != BeastDef.Rarity.BOSS:
			for g in guards:
				if not g.guard_ready() or g.blocked.size() >= g.def.block_count:
					continue
				if e.distance <= g.block_distance and next_distance >= g.block_distance:
					next_distance = g.block_distance
					e.blocked_by = g.slot
					g.blocked.append(e.id)
					events.append({"type": "blocked", "enemy_id": e.id, "slot": g.slot})
					break
		e.distance = next_distance
		if e.distance >= path.length:
			e.distance = path.length
			e.alive = false
			e.leaked = true
			ding_hp -= e.def.leak_damage
			_resolve(e)
			events.append({"type": "leaked", "enemy_id": e.id, "damage": e.def.leak_damage, "position": path.points[path.points.size() - 1]})


func _update_guards() -> void:
	for t: TowerUnit in towers.values():
		if not t.is_guard:
			continue
		if t.guard_down_ticks > 0:
			t.guard_down_ticks -= 1
			if t.guard_down_ticks == 0:
				t.guard_hp = t.guard_hp_max
				events.append({"type": "guard_recovered", "slot": t.slot})
		elif t.guard_active and t.guard_hp <= 0.0:
			t.guard_hp = 0.0
			t.guard_down_ticks = maxi(t.def.guard_recover_ticks, 1)
			_release_blocked(t)
			events.append({"type": "guard_broken", "slot": t.slot})


func _release_blocked(t: TowerUnit) -> void:
	for id in t.blocked:
		var e := enemy_by_id(id)
		if e != null and e.blocked_by == t.slot:
			e.blocked_by = -1
	t.blocked.clear()


func _guards_by_distance() -> Array[TowerUnit]:
	var out: Array[TowerUnit] = []
	for t: TowerUnit in towers.values():
		if t.is_guard and t.guard_active:
			out.append(t)
	out.sort_custom(func(a: TowerUnit, b: TowerUnit) -> bool:
		return a.block_distance < b.block_distance or (a.block_distance == b.block_distance and a.slot < b.slot))
	return out


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
	events.append({"type": "hit", "enemy_id": e.id, "position": p.position, "damage": p.damage, "crit": p.crit, "element": p.element})
	for eff in p.on_hit:
		match eff.op:
			&"slow":
				e.slow_multiplier = eff.amount if e.slow_ticks <= 0 else minf(e.slow_multiplier, eff.amount)
				e.slow_ticks = maxi(e.slow_ticks, eff.duration_ticks)
			&"burn":
				_apply_burn(e, eff.amount, eff.duration_ticks)
			&"dry":
				if e.slow_ticks > 0:
					e.hp -= p.damage * eff.amount
					events.append({"type": "hit", "enemy_id": e.id, "position": p.position, "damage": p.damage * eff.amount, "crit": true, "element": p.element})
					e.slow_ticks = 0
					e.slow_multiplier = 1.0
			&"splash":
				for other in enemies:
					if other != e and other.alive and enemy_position(other).distance_to(p.position) <= eff.radius:
						_damage_enemy(other, p.damage * eff.amount)
			&"ignite_nearby":
				var nearest: EnemyUnit = null
				var best := eff.radius
				for other in enemies:
					if other == e or not other.alive:
						continue
					var d := enemy_position(other).distance_to(p.position)
					if d <= best:
						best = d
						nearest = other
				if nearest != null:
					_apply_burn(nearest, eff.amount, eff.duration_ticks)
	if e.hp <= 0.0:
		_kill(e)


func _apply_burn(e: EnemyUnit, per_tick: float, duration: int) -> void:
	e.burn_per_tick = per_tick if e.burn_ticks <= 0 else maxf(e.burn_per_tick, per_tick)
	e.burn_ticks = maxi(e.burn_ticks, duration)


## 技能和溅射用的直接伤害，不触发 on_hit。
func _damage_enemy(e: EnemyUnit, amount: float) -> void:
	e.hp -= amount
	events.append({"type": "hit", "enemy_id": e.id, "position": enemy_position(e), "damage": amount, "crit": false, "element": &"none"})
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
	events.append({"type": "killed", "enemy_id": e.id, "position": pos, "spirit": e.def.spirit_reward, "element": e.def.element, "rarity": e.def.rarity})
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
		if t.def.crit_chance > 0.0 and _rng.next_float() < t.def.crit_chance:
			p.damage *= t.def.crit_multiplier
			p.crit = true
		p.element = t.def.element
		p.on_hit = _on_hit_effects_for(t)
		target.reserved_damage += p.damage
		projectiles.append(p)
		t.cooldown = t.def.attack_interval_ticks
		t.last_fire_tick = tick
		events.append({"type": "fired", "slot": s, "projectile_id": p.id})


## 本塔自己的 on_hit 特性 + 作用域匹配本塔五行（或不限五行）的阵法、法宝、守鼎人 on_hit 效果。
func _on_hit_effects_for(t: TowerUnit) -> Array[EffectDef]:
	var out: Array[EffectDef] = []
	for entry: Dictionary in _effects.get(&"on_hit", []):
		var source: TowerUnit = entry.tower
		var scope: StringName = entry.scope
		if source == t or (source == null and (scope == &"" or scope == t.def.element)):
			out.append(entry.effect)
	return out


## 射程内、没被预定致死、沿路径走得最远的敌人。
func _pick_target(t: TowerUnit) -> EnemyUnit:
	var best: EnemyUnit = null
	for e in enemies:
		if not e.alive or e.hp - e.reserved_damage <= 0.0:
			continue
		if t.position.distance_to(enemy_position(e)) > tower_range(t):
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
	for t: TowerUnit in towers.values():
		if t.blocked.is_empty():
			continue
		var still: Array[int] = []
		for id in t.blocked:
			var e := enemy_by_id(id)
			if e != null and e.blocked_by == t.slot:
				still.append(id)
		t.blocked = still


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
	_capture_bonus = 0.0
	if keeper != null:
		for eff in keeper.passives:
			_register(null, eff, eff.element_scope)
	for relic in _relics:
		for eff in relic.effects:
			_register(null, eff, eff.element_scope)
	var slots := towers.keys()
	slots.sort()
	var counts := {}
	for s: int in slots:
		var t: TowerUnit = towers[s]
		counts[t.def.element] = int(counts.get(t.def.element, 0)) + 1
		for eff in t.def.traits:
			_register(t, eff, eff.element_scope)
	active_formations.clear()
	for f in _formations:
		var reached: FormationTier = null
		for tier in f.tiers:
			if int(counts.get(f.element, 0)) >= tier.count:
				reached = tier
		if reached == null:
			continue
		active_formations[f.element] = reached.count
		for eff in reached.effects:
			_register(null, eff, f.element)
	for entry: Dictionary in _effects.get(&"passive", []):
		var eff: EffectDef = entry.effect
		match eff.op:
			&"global_damage_pct":
				_global_damage_bonus += eff.amount
			&"capture_threshold_bonus":
				_capture_bonus += eff.amount
	_recompute_bonuses()


func _register(t: TowerUnit, eff: EffectDef, scope: StringName) -> void:
	if not _effects.has(eff.trigger):
		_effects[eff.trigger] = []
	_effects[eff.trigger].append({"tower": t, "effect": eff, "scope": scope})


func _recompute_bonuses() -> void:
	var passives: Array = _effects.get(&"passive", [])
	for t: TowerUnit in towers.values():
		var bonus := 0.0
		var guard_pct := 0.0
		for o: TowerUnit in towers.values():
			if o == t or o.position.distance_to(t.position) > battle.adjacency_radius:
				continue
			if Elements.generates(o.def.element, t.def.element):
				bonus += _chart.generate_bonus
			for eff in o.def.traits:
				if eff.trigger == &"passive" and eff.op == &"adjacent_damage_pct":
					bonus += eff.amount
		for entry: Dictionary in passives:
			var eff: EffectDef = entry.effect
			var scope: StringName = entry.scope
			if entry.tower != null:
				continue
			if eff.op == &"element_damage_pct" and scope == t.def.element:
				bonus += eff.amount
			elif eff.op == &"guard_hp_pct" and (scope == &"" or scope == t.def.element):
				guard_pct += eff.amount
		t.damage_bonus = bonus
		if t.is_guard:
			var new_max := t.def.guard_hp * TIER_GUARD_MULT[clampi(t.instance.tier, 1, BeastInstance.MAX_TIER)] * LEVEL_GUARD_MULT[clampi(t.level, 1, MAX_LEVEL)] * (1.0 + guard_pct)
			if t.guard_hp_max > 0.0 and t.guard_down_ticks == 0:
				t.guard_hp = t.guard_hp * new_max / t.guard_hp_max
			t.guard_hp_max = new_max
