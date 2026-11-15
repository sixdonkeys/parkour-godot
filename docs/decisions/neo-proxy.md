# Decision: neo-proxy

- **Options:**
  1. Take the development machine's numbers as they are. Rejected: the M1 Pro has roughly twice the Neo's graphics throughput and over three times its memory bandwidth, so raw numbers would judge the Neo far too leniently.
  2. Scale GPU time by a fixed factor from published benchmarks, check wall-clock frame time against the raw budget as well, and correct the factor from the Neo's own result folders as they arrive.
  3. Throttle the development machine to imitate the Neo (lower GPU clocks, a frame limiter). Not possible from inside the sandbox without root, and clock limits don't imitate bandwidth.
- **Sources:** `docs/survey/neo-proxy.md` — MacRumors first Neo benchmarks; MacMyths A18 Pro vs M1 Pro comparison; RenderingServer class reference 4.7.2; local `vulkaninfo`.
- **Choice:** option 2. A proxy frame-time figure passes only if both hold:
  - (a) Wall-clock frame time on the development machine meets the raw budget: P95 ≤ 16.7 ms and P99 ≤ 22 ms.
  - (b) GPU time × **2.5** meets the same budget: GPU P95 ≤ 6.68 ms and P99 ≤ 8.8 ms on the development machine.

  Details:
  - Why 2.5: Geekbench Metal puts a 14-core M1 Pro near 2× the Neo's 5-core A18 Pro, and this 16-inch M1 Pro has the 16-core GPU, so about 2.2×. A further margin of about 15% covers the unknown gap between Honeykrisp/Vulkan here and Metal on the Neo, plus the Neo's fanless thermals.
  - Benchmarks run with vsync off and `--fixed-fps` test timing, so the GPU stays at full clock and GPU time isn't inflated by a frame cap.
  - Memory is compared to the 4 GB budget as measured; no factor, since the budget already leaves the Neo's other 4 GB to macOS.
  - Every proxy number is labelled `proxy` in the log, with the factor used.
  - When a Neo result folder arrives, `CALIBRATION.md` compares the prediction with the measurement, and the factor in this record is corrected.
- **Reason:** the factor is derived from published measurements, not a hunch, and is stricter than the benchmark ratio, so the proxy never judges more leniently than the Neo. Checking wall-clock time too catches CPU-bound frames that a GPU factor alone would miss.
- **Licence:** nothing is depended on beyond the Godot engine (MIT).
