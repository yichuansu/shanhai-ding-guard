extends TestCase


func test_path_length_and_position() -> void:
	var p := PathCurve.new(PackedVector2Array([Vector2(0, 0), Vector2(300, 0), Vector2(300, 400)]))
	check_near(p.length, 700.0)
	check_eq(p.position_at(150.0), Vector2(150, 0))
	check_eq(p.position_at(500.0), Vector2(300, 200))
	check_eq(p.position_at(-5.0), Vector2(0, 0))
	check_eq(p.position_at(9999.0), Vector2(300, 400))


func test_element_relations() -> void:
	var chart := ElementChart.new()
	check_near(chart.multiplier(Elements.MU, Elements.TU), 1.5, 0.0001, "木克土")
	check_near(chart.multiplier(Elements.TU, Elements.MU), 0.7, 0.0001, "土被木克")
	check_near(chart.multiplier(Elements.MU, Elements.HUO), 1.0, 0.0001, "木生火不改伤害")
	check_near(chart.multiplier(Elements.MU, Elements.NONE), 1.0)
	check(Elements.generates(Elements.SHUI, Elements.MU), "水生木")
	for e in Elements.ALL:
		check(Elements.OVERCOMES.has(e) and Elements.GENERATES.has(e), "%s 关系完整" % e)


func test_rng_is_reproducible_and_derived_streams_differ() -> void:
	var a := RngStream.new(123)
	var b := RngStream.new(123)
	for i in 20:
		check_eq(a.next_int(0, 1000), b.next_int(0, 1000))
	check(RngStream.derive_seed(1, "map") != RngStream.derive_seed(1, "battle"), "不同标签派生出不同种子")
	check_eq(RngStream.derive_seed(7, "x"), RngStream.derive_seed(7, "x"))


func test_sim_clock_speed_only_changes_tick_rate() -> void:
	var c1 := SimClock.new()
	var c2 := SimClock.new()
	c2.speed = 2.0
	var t1 := 0
	var t2 := 0
	for i in 60:
		t1 += c1.advance(1.0 / 60.0)
		t2 += c2.advance(1.0 / 60.0)
	check_eq(t1, 10, "1 倍速 1 秒 10 拍")
	check_eq(t2, 20, "2 倍速 1 秒 20 拍")
	c1.paused = true
	check_eq(c1.advance(1.0), 0, "暂停不推进")


func test_wave_director_uses_literal_intervals() -> void:
	var s := SpawnEntry.new()
	s.beast_id = &"a"
	s.count = 3
	s.interval_ticks = 5
	var w1 := WaveDef.new()
	w1.spawns = [s]
	var s2 := SpawnEntry.new()
	s2.beast_id = &"b"
	s2.count = 1
	var w2 := WaveDef.new()
	w2.gap_ticks_before = 10
	w2.spawns = [s2]
	var wd := WaveDirector.new([w1, w2])
	var spawn_ticks: Array[int] = []
	for t in range(1, 40):
		for req in wd.step():
			spawn_ticks.append(t)
	check_eq(spawn_ticks, [1, 6, 11, 21] as Array[int], "间隔 5，下一波间隔 10")
	check(wd.finished_spawning, "出完")
