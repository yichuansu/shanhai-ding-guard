class_name SimClock
extends RefCounted
## 墙钟到逻辑 tick 的换算。逻辑固定 10Hz；倍速只让同一帧多跑 tick，不改单次结算。

const TICK_SECONDS := 0.1
const MAX_TICKS_PER_FRAME := 8
## 浮点累加误差容差：60 帧 × (1/60) 秒应恰好得到 10 拍。
const EPSILON := 1e-6

var speed := 1.0
var paused := false
var _accumulator := 0.0


## 返回本帧应推进的 tick 数。卡顿时最多补 MAX_TICKS_PER_FRAME 拍，其余丢弃，避免雪崩。
func advance(delta: float) -> int:
	if paused:
		return 0
	_accumulator += delta * speed
	var ticks := 0
	while _accumulator >= TICK_SECONDS - EPSILON and ticks < MAX_TICKS_PER_FRAME:
		_accumulator = maxf(_accumulator - TICK_SECONDS, 0.0)
		ticks += 1
	if ticks == MAX_TICKS_PER_FRAME and _accumulator >= TICK_SECONDS:
		_accumulator = 0.0
	return ticks


## 两拍之间的插值系数，供表现层用。
func alpha() -> float:
	return clampf(_accumulator / TICK_SECONDS, 0.0, 1.0)
