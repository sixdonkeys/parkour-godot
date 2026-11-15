extends RefCounted
## Frame-time instrument. A frame time is the wall time between consecutive
## RenderingServer.frame_post_draw signals; GPU time is the root viewport's
## measured render time for the same frame (ARCHITECTURE.md, Measured events).

const BUDGET_P95_MS := 16.7
const BUDGET_P99_MS := 22.0
const PROXY_GPU_FACTOR := 2.5  # decision neo-proxy

var frame_ms: PackedFloat64Array = []
var gpu_ms: PackedFloat64Array = []
var cpu_ms: PackedFloat64Array = []
var draw_calls: PackedInt64Array = []
var primitives: PackedInt64Array = []
var _last_usec := -1
var _vp_rid: RID
var excluded_capture_frames := 0
var capture_indices: PackedInt32Array = []
var _skip_next := false


func start(viewport: Viewport) -> void:
	_vp_rid = viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	_last_usec = -1


## The frame just sampled was followed by a capture (PNG save).
func mark_capture() -> void:
	_skip_next = true
	capture_indices.append(frame_ms.size())


## Call once per frame_post_draw.
func sample() -> void:
	var now := Time.get_ticks_usec()
	if _skip_next:
		# The previous frame saved a PNG on the main thread; that cost belongs
		# to the instrument, not the game, so this frame's time is not counted.
		_skip_next = false
		excluded_capture_frames += 1
	elif _last_usec >= 0:
		frame_ms.append((now - _last_usec) / 1000.0)
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid))
		cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid))
		draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	_last_usec = now


static func percentile(values: PackedFloat64Array, p: float) -> float:
	if values.is_empty():
		return NAN
	var s := values.duplicate()
	s.sort()
	var idx := clampi(int(ceil(p / 100.0 * s.size())) - 1, 0, s.size() - 1)
	return s[idx]


static func share_within(values: PackedFloat64Array, limit: float) -> float:
	if values.is_empty():
		return NAN
	var n := 0
	for v in values:
		if v <= limit:
			n += 1
	return float(n) / values.size()


static func histogram(values: PackedFloat64Array, bucket_ms := 0.5, max_ms := 50.0) -> Dictionary:
	var buckets := {}
	var over := 0
	for v in values:
		if v >= max_ms:
			over += 1
			continue
		var b := snappedf(floor(v / bucket_ms) * bucket_ms, 0.001)
		var key := "%.1f" % b
		buckets[key] = buckets.get(key, 0) + 1
	return {"bucket_ms": bucket_ms, "buckets": buckets, "over_max": over, "max_ms": max_ms}


func report(proxy: bool) -> Dictionary:
	var p95 := percentile(frame_ms, 95)
	var p99 := percentile(frame_ms, 99)
	var g95 := percentile(gpu_ms, 95)
	var g99 := percentile(gpu_ms, 99)
	var wall_ok := p95 <= BUDGET_P95_MS and p99 <= BUDGET_P99_MS
	var gpu_ok := g95 * PROXY_GPU_FACTOR <= BUDGET_P95_MS and g99 * PROXY_GPU_FACTOR <= BUDGET_P99_MS
	var mean_dc := 0.0
	var max_dc := 0
	for d in draw_calls:
		mean_dc += d
		max_dc = maxi(max_dc, d)
	var max_prim := 0
	for p in primitives:
		max_prim = maxi(max_prim, p)
	return {
		"frames": frame_ms.size(),
		"excluded_capture_frames": excluded_capture_frames,
		"vsync_mode": ["disabled", "enabled", "adaptive", "mailbox"][DisplayServer.window_get_vsync_mode()],
		"frame_ms": {"p50": percentile(frame_ms, 50), "p95": p95, "p99": p99,
			"max": percentile(frame_ms, 100),
			"share_within_16_7": share_within(frame_ms, 16.7),
			"share_within_22": share_within(frame_ms, 22.0)},
		"gpu_ms": {"p50": percentile(gpu_ms, 50), "p95": g95, "p99": g99},
		"cpu_render_ms": {"p50": percentile(cpu_ms, 50), "p95": percentile(cpu_ms, 95)},
		"histogram": histogram(frame_ms),
		"series_ms": frame_ms,
		"capture_after_index": capture_indices,
		"draw_calls": {"mean": mean_dc / maxf(1, draw_calls.size()), "max": max_dc},
		"primitives_max": max_prim,
		"budget": {
			"proxy": proxy,
			"proxy_gpu_factor": PROXY_GPU_FACTOR if proxy else 1.0,
			"wall_clock_meets_budget": wall_ok,
			"gpu_scaled_meets_budget": gpu_ok if proxy else null,
			"pass": wall_ok and (gpu_ok or not proxy),
		},
	}
