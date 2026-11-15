# Survey: neo-proxy

## MacRumors, "First MacBook Neo Benchmarks Are In" (2026-03-05) — https://www.macrumors.com/2026/03/05/macbook-neo-first-benchmarks/

> The ‌MacBook Neo‌ uses the same 6-core A18 Pro chip that was first introduced in the iPhone 16 Pro, but it has one fewer GPU core.

> The ‌MacBook Neo‌ earned a single-core score of 3461 and a multi-core score of 8668 , along with a Metal score of 31286 .

> M1 MacBook Air - 2346 single-core, 8342 multi-core, 33148 Metal M4 MacBook Air - 3696 single-core, 14730 multi-core, 54630 Metal

## MacMyths, "A18 Pro GPU vs M1 Pro 14-Core GPU: Which Is Faster?" — https://macmyths.com/a18-pro-gpu-vs-m1-pro-14-core-gpu-which-is-faster/

> The 14-core M1 Pro GPU is roughly twice as fast as the MacBook Neo’s 5-core A18 Pro in the cited Geekbench Metal submissions.

> the MacBook Neo’s 5-core A18 Pro has 60GB/s bandwidth, versus 200GB/s for the M1 Pro.

> GPU core counts are not directly comparable across generations: one A18 Pro core is not necessarily equivalent to one M1 Pro core.

> The cited Geekbench Browser Metal submissions put the 14-core M1 Pro at roughly twice the score of the MacBook Neo’s A18 Pro, although the results should be treated as directional rather than as a laboratory-controlled comparison.

## RenderingServer class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/RenderingServer.xml

> [b]Note:[/b] When GPU utilization is low enough during a certain period of time, GPUs will decrease their power state (which in turn decreases core and memory clock speeds). This can cause the reported GPU time to increase if GPU utilization is kept low enough by a framerate cap (compared to what it would be at the GPU's highest power state). Keep this in mind when benchmarking using [method viewport_get_measured_render_time_gpu].

## Local probe — `vulkaninfo`, 2026-11-15

> 	deviceName        = Apple M1 Pro (G13S C0)
> 	driverName                                           = Honeykrisp
> 	driverInfo                                           = Mesa 26.2.6
