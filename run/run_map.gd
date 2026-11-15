class_name RunMap
extends RefCounted
## 一州的分支路线图。由种子完全决定，存档只记种子，读档时重新生成。
## 结构：第 0 层 3 个战斗 → 中间若干层混合节点 → 倒数第二层祭祀 → 首领。

const DEFAULT_LAYERS := 8
const EXTRA_EDGE_CHANCE := 0.35

var nodes: Array[MapNode] = []
var layers: Array[PackedInt32Array] = []


static func generate(rng: RngStream, layer_count: int = DEFAULT_LAYERS) -> RunMap:
	assert(layer_count >= 4)
	var m := RunMap.new()
	for layer in layer_count:
		var count := 1
		if layer == 0:
			count = 3
		elif layer < layer_count - 2:
			count = rng.next_int(2, 4)
		elif layer == layer_count - 2:
			count = rng.next_int(1, 2)
		var ids := PackedInt32Array()
		for col in count:
			var n := MapNode.new()
			n.id = m.nodes.size()
			n.layer = layer
			n.column = col
			n.x = 0.5 if count == 1 else float(col) / float(count - 1)
			n.type = _roll_type(rng, layer, layer_count)
			m.nodes.append(n)
			ids.append(n.id)
		m.layers.append(ids)
	m._connect(rng)
	m._ensure_type(rng, MapNode.Type.SHOP)
	m._ensure_type(rng, MapNode.Type.FORGE)
	return m


## 当前节点之后可以去的节点。-1 表示还没出发。
func available_from(node_id: int) -> PackedInt32Array:
	if node_id < 0:
		return layers[0]
	return nodes[node_id].next


func boss_id() -> int:
	return layers[layers.size() - 1][0]


static func _roll_type(rng: RngStream, layer: int, layer_count: int) -> MapNode.Type:
	if layer == 0:
		return MapNode.Type.BATTLE
	if layer == layer_count - 1:
		return MapNode.Type.BOSS
	if layer == layer_count - 2:
		return MapNode.Type.REST
	var weights := {
		MapNode.Type.BATTLE: 45.0,
		MapNode.Type.EVENT: 22.0,
		MapNode.Type.SHOP: 10.0,
		MapNode.Type.ELITE: 12.0 if layer >= 3 else 0.0,
		MapNode.Type.FORGE: 11.0 if layer >= 2 else 0.0,
	}
	return rng.weighted_pick(weights)


func _connect(rng: RngStream) -> void:
	for i in layers.size() - 1:
		var cur := layers[i]
		var nxt := layers[i + 1]
		var has_incoming := {}
		for id in cur:
			var nearest := _nearest_index(nodes[id].x, nxt)
			_add_edge(id, nxt[nearest])
			has_incoming[nxt[nearest]] = true
			if rng.chance(EXTRA_EDGE_CHANCE) and nxt.size() > 1:
				var side := nearest + (1 if rng.chance(0.5) else -1)
				side = clampi(side, 0, nxt.size() - 1)
				_add_edge(id, nxt[side])
				has_incoming[nxt[side]] = true
		for target in nxt:
			if not has_incoming.has(target):
				_add_edge(cur[_nearest_index(nodes[target].x, cur)], target)
	for n in nodes:
		n.next.sort()


func _ensure_type(rng: RngStream, t: MapNode.Type) -> void:
	var candidates: Array[int] = []
	for n in nodes:
		if n.type == t:
			return
		var middle := n.layer >= 1 and n.layer < layers.size() - 2
		if middle and (n.type == MapNode.Type.BATTLE or n.type == MapNode.Type.EVENT):
			candidates.append(n.id)
	if not candidates.is_empty():
		nodes[candidates[rng.next_int(0, candidates.size() - 1)]].type = t


func _nearest_index(x: float, ids: PackedInt32Array) -> int:
	var best := 0
	for i in ids.size():
		if absf(nodes[ids[i]].x - x) < absf(nodes[ids[best]].x - x):
			best = i
	return best


func _add_edge(from_id: int, to_id: int) -> void:
	if not nodes[from_id].next.has(to_id):
		nodes[from_id].next.append(to_id)
