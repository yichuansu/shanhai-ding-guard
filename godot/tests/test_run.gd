extends TestCase


func test_map_is_reproducible() -> void:
	var a := RunMap.generate(RngStream.new(99))
	var b := RunMap.generate(RngStream.new(99))
	check_eq(a.nodes.size(), b.nodes.size())
	for i in a.nodes.size():
		check_eq(a.nodes[i].type, b.nodes[i].type)
		check_eq(a.nodes[i].next, b.nodes[i].next)


func test_map_structure_over_many_seeds() -> void:
	for seed in 200:
		var m := RunMap.generate(RngStream.new(seed))
		var last := m.layers.size() - 1
		check_eq(m.layers[last].size(), 1, "种子 %d 只有一个首领" % seed)
		check_eq(m.nodes[m.boss_id()].type, MapNode.Type.BOSS)
		var incoming := {}
		var types := {}
		for n in m.nodes:
			types[n.type] = true
			if n.layer < last:
				check(not n.next.is_empty(), "种子 %d 节点 %d 有出路" % [seed, n.id])
			for t in n.next:
				check_eq(m.nodes[t].layer, n.layer + 1, "只连下一层")
				incoming[t] = true
			if n.layer == 0:
				check_eq(n.type, MapNode.Type.BATTLE, "第一层都是战斗")
			if n.type == MapNode.Type.ELITE:
				check(n.layer >= 3, "精英不早于第 3 层")
		for n in m.nodes:
			if n.layer > 0:
				check(incoming.has(n.id), "种子 %d 节点 %d 可达" % [seed, n.id])
		check(types.has(MapNode.Type.SHOP), "种子 %d 有集市" % seed)
		check(types.has(MapNode.Type.FORGE), "种子 %d 有炼鼎" % seed)


func test_run_state_round_trip() -> void:
	var r := RunState.new_run(2024, [&"jingwei", &"bifang"] as Array[StringName])
	var first := r.available_nodes()[0]
	check(r.enter_node(first), "可以进入第一层")
	check(not r.enter_node(first), "不能重复进入同一节点")
	r.shells = 17
	r.relic_ids.append(&"hetu")
	r.add_beast(&"jingwei")
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	check(restored != null, "读档成功")
	check_eq(restored.to_dict(), RunState.from_dict(r.to_dict()).to_dict(), "存读一致")
	check_eq(restored.map.nodes.size(), r.map.nodes.size(), "路线图由种子重建")
	check_eq(restored.roster.size(), 3)
	check_eq(restored.available_nodes(), r.available_nodes())


func test_unknown_schema_is_rejected() -> void:
	check(RunState.from_dict({"schema": 999}) == null, "不认识的版本返回 null")


func test_roster_cap_and_merge() -> void:
	var r := RunState.new_run(1, [] as Array[StringName])
	for i in RunState.DEFAULT_ROSTER_CAP:
		check(r.add_beast(&"jingwei") != null, "未满可加入")
	check(r.add_beast(&"bifang") == null, "满了加不进")
	var merged := r.merge_first_pair()
	check(merged != null and merged.tier == 2, "两只合成 2 阶")
	check_eq(r.roster.size(), RunState.DEFAULT_ROSTER_CAP - 1)


func test_profile_bestiary() -> void:
	var p := Profile.new()
	check(p.record_capture(&"dangkang"), "首次捕获")
	check(not p.record_capture(&"dangkang"), "第二次不是首次")
	var restored := Profile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	check(restored.has_captured(&"dangkang"), "读档后仍在图鉴里")
	check_eq(int(restored.bestiary["dangkang"]["captures"]), 2)


func test_save_store_round_trip() -> void:
	var path := "user://test_save.json"
	SaveStore.delete(path)
	check_eq(SaveStore.load_json(path), {}, "不存在时返回空")
	check_eq(SaveStore.save_json(path, {"a": 1}), OK)
	check_eq(SaveStore.save_json(path, {"a": 2}), OK, "覆盖写")
	check_eq(int(SaveStore.load_json(path)["a"]), 2)
	SaveStore.delete(path)
