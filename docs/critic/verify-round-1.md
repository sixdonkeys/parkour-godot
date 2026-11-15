# Critic: verify, round 1

- Commit graded: `673d84fc1f8fccdbd4755eb64b228c87aed25d96` (working tree clean at start; `docs/CRITIC-PROMPT.md` carries the fixed text plus nothing else).
- Date: 2026-11-15. Machine: MacBook Pro 16" M1 Pro, Fedora Asahi 44, Honeykrisp (Vulkan), live session GNOME (Wayland). Everything that draws ran outside the sandbox.
- **Gate: not passed. Score: none** (only a module through the gate gets one).
- Neo: `remote neo check` → `cannot reach neo over SSH (ssh: Could not resolve hostname neo …)`. No Neo result folder exists. Every number here is a proxy under `neo-proxy`: **neo-unverified**.
- Web access: yes. Sources verified (below).

## What was checked, and what held

| Check | Result | Evidence |
|---|---|---|
| ARCHITECTURE.md against the brief | Every course rule, window rule and budget bullet is present word for word (checked by script); all 22 hard problems listed; module table and build order match. | — |
| Decision records verify depends on (verification-rendering, tick-and-frame, windowing, mac-delivery, asset-pipeline, sound, neo-proxy, remote-test) | All fields filled; every record has a survey file with excerpts. | `docs/decisions/`, `docs/survey/` |
| Two sources fetched by the critic | Engine.xml at `4.7.2-stable`: both quoted excerpts found verbatim (physics jitter-fix note; "racing games may benefit…"). MacMyths A18 Pro vs M1 Pro: all four quoted excerpts found verbatim. | fetched this round |
| Packed-file list against ASSETS.md | 176 files per export; every `.godot/imported` file is traced back to its source; 48 Poly Haven files are covered by the `game/assets/polyhaven/` entry; nothing unlisted. | `docs/evidence/verify/round-1/build/packed-*.json` |
| Two ASSETS.md entries fetched by the critic | Godot `LICENSE.txt` at `4.7.2-stable` matches the quote. Poly Haven licence page holds both quoted sentences. (The USGS public-domain sentence was also found in the tile's metadata on disk.) | fetched this round |
| `docs/upstream/` | Empty, and no adopted code exists (`game/thirdparty/` absent). Nothing to check. | — |
| Builder's six proofs re-run by the critic | All six pass again: image, frame time (p50 33.353 ms vs 33.333), memory (texture delta 67,633,152 vs 67,108,864), sound (−6.021 dBFS; clipping found), build (known 10,485,760-byte file listed; `assets/planted.bin` flagged), window (GNOME; ui-outside fixture found exactly one element). | `docs/evidence/verify/critic-round-1/proofs/` |
| Critic's own fixtures | Frame time at 20 fps: p50 49.995 ms ✔. Image: real still against itself SSIM 1, histogram 0; half of an image set white → 0.5 exactly ✔. Build: own package, a 3,000,001-byte file listed at that size, an unlisted `thirdparty/` file flagged, a listed `assets/` file not flagged ✔. Window: quarter column, fifth-height strip, 0.75×0.6, fullscreen on/off, focus loss: all filled, zero errors ✔. Missing scene: engine exit ignored, 8 errors reported ✔. **Memory ✘ (issue 2). Sound ✘ (issue 3).** | `docs/evidence/verify/critic-round-1/own/`, `critic-results.json` |
| Critic's own preset (`critic-verify-empty-still-low`) and test-vs-normal pairs | Zero errors. Pairs on the empty scene: SSIM 1.0, but the stills are blank (issue 4). Pair on a scene with content (`core-profile-neo-stress-still`): SSIM 1.0, zero pixels differ ✔. | `docs/evidence/verify/critic-round-1/presets/` |
| Benchmark mode of the exported build | Runs, writes logs and PNGs, self-terminates cleanly. **Measures a different quality profile from the one in the repository (issue 1).** | `docs/evidence/verify/critic-round-1/bench-linux-arm64/` |
| Remote loop | `check` on an unresolvable host: one plain line, exit 1, 0.09 s ✔. Full `bench` against `local-folder` at the graded commit: export → copy → run → fetch → `HONESTY.json` all worked; the run was correctly marked void (the game lost focus during it). | `docs/local-folder/2026-11-15-673d84fc1f8f/` |
| Reference set | 71 files, 71 ledger entries, every SHA-256 matches; licences all PD / CC0 / CC BY / CC BY-SA; every city photo dated 2016 or later; desert includes Sabino Canyon, Mount Lemmon and Javelina Rocks. One folder short (issue 5). Not yet approved (Nick's step). | `reference/LEDGER.md` |
| Zero errors | Zero engine errors in every critic run except the deliberate missing-scene fixture. | `critic-results.json` |

## Ranked issues

1. **Exported builds don't use the repository's `neo` profile, so benchmark mode measures something else.** `game/profiles/neo.tres` sets `upscalers = ["metalfx_temporal", "fsr", "bilinear"]` and tool runs pick `fsr` (FSR1 + SMAA). Every exported build picks `fsr2`, the script default in `core/quality_profile.gd:14`. The converted resource packed into the build (`.godot/exported/133200997/export-3830f…-neo.res`, 903 bytes) has no upscaler strings in it at all. Effect: the empty scene costs GPU p50 ~4.2 ms in the tool and 8.6–9.7 ms in the export. All four bench presets fail the frame budget in the export (`verify-empty-still` GPU p95 8.73 ms against the 6.68 ms proxy limit; wall p95 19.7 ms) but pass in the tool. Reproduced twice: once on the builder's `builds/verify-r1` export, once on a fresh export at the graded commit through `remote local-folder bench`. The builder's own benchmark-mode evidence (`round-1/bench-linux-arm64`, commit `e0c212f-dirty`) predates the profile and is stale. On the Neo, MetalFX comes first in both lists, so the effect there may be nil, but that is unproved. The mechanism inside the export's text-to-binary conversion has not been traced; that is for the builder. **Fix:** make the export carry the profile as written, and add a check to the build step: the exported build's `describe()` for each profile must equal the source's.
   Evidence: `docs/evidence/verify/critic-round-1/bench-linux-arm64/*/log.json` (`profile.settings.chosen_upscaler`), `docs/local-folder/2026-11-15-673d84fc1f8f/`, compared with `docs/evidence/verify/critic-round-1/presets/verify-empty-still/log.json`.

2. **The memory instrument passes only under a redefined budget, and its leak flag misfires.**
   - (a) The brief says memory must be "back within 5% of the pre-load figure". `ARCHITECTURE.md` (Measured events) redefines the pre-load figure as the reading after an earlier load/unload cycle. On the builder's own fixture the raw return is 1.176 (critic re-run: 1.176); on the critic's 2048² fixture it is 1.12. The fixture README's known answer, "back to the baseline after unload", is not met raw. Redefining what the budget compares against loosens it, and loosening is Nick's call (brief item 1). Either make the literal pre-load reading hold (for example, grow the staging buffer and settle the heap in the base scene before the baseline), or write the case into `docs/WAITING.md`.
   - (b) On the critic's 2048×2048 fixture (16 MiB), `grows_each_cycle` reads **true**, although six pre-cycles show the after-unload total flat: 442.99 → 443.60 → 444.04 → 444.20 → 444.47 MB. Then the measured cycle jumps to 455.57 MB, and process RSS jumps +11 MB with it. The flag compares the measured cycle (frame stats, logging, a longer run) with a pre-cycle, which is not like for like. The builder's 64 MiB fixture happens to avoid this. **Fix:** compare like-for-like cycles, and prove the flag on a fixture of a second size plus one that leaks on purpose.
   Evidence: `docs/evidence/verify/critic-round-1/own/memory-2048/`, `own/memory-2048-6cycles/`, `proofs/memory/`.

3. **The sound fixture plays the wrong level for its first ~0.4 s.** `tone.gd` fills its buffer in `_ready()` at the default amplitude 0.5. `verify.gd` calls `configure_fixture()` only after `add_child` (lines 253–258). The critic's −12.04 dBFS tone therefore measured a −6.02 dBFS peak. The WAV shows 0.5 for the first eight 50 ms windows, then 0.25, and the steady RMS (−15.05) is right. The instrument reports truthfully; the fixture is wrong. The builder's −6 fixture can't see this because its amplitude equals the default. The clipping fixture's RMS miss (−1.39 against −1.07 expected) is this same defect, which the code comment in `prove_sound` puts down to "generator start-up can leave a short gap". That explanation has no traced mechanism. **Fix:** configure before the first fill, and re-prove.
   Evidence: `docs/evidence/verify/critic-round-1/own/tone-minus12/`, `proofs/verify-sound-tone-clipping/`.

4. **verify's showcase and its test-vs-normal pair are blank frames.** Every verify still is one flat colour, RGB (76, 76, 76): the `verify-empty-still` still, every frame of the `verify-empty-path` strip, and both halves of the pair. The empty scene has no geometry or light. So SSIM 1.0 proves nothing, and a camera path whose strip never changes doesn't show the path working. The capture tool does work on content (`core-profile-neo-stress-still`), and the critic's pair on that preset matched exactly. **Fix:** give the showcase something to draw (a lit fixture with geometry), capture the pair on it, and have the log report the noise figure the pair is judged against ("within the noise the log reports").

5. **The reference set is one photograph short, and the search parks work the builder could still do.** `mountain/closeup/lowsun` has 1 of the required 2. The search shown in NOTES.md and WAITING.md is Wikimedia Commons only. The brief names the photo libraries of the National Park Service, the Forest Service, the Geological Survey and the Library of Congress. The Black Hills National Forest and Wind Cave / Jewel Cave / Mount Rushmore park galleries were not searched. Search them before asking Nick for a photo of his own. Approval (`reference/APPROVED.md`) is still Nick's step.

6. **The log doesn't name the graphics driver.** In every log, `adapter_driver` is `["", ""]`. The brief requires "the graphics adapter and driver in use", and Honeykrisp / Mesa 26.2.6 appears nowhere in the run logs. Record it, from the engine where possible, otherwise from the orchestrator (`vulkaninfo --summary`) beside the log. The exported benchmark mode needs it too.

7. **Remote honesty treats "couldn't tell" as honest.** `HONESTY.json` lists `front_app` and `display_awake` as `unverifiable` yet sets `void: false` (`docs/local-folder/2026-11-15-62b2ca8778fe/`). The brief makes a remote number honest only if the display was awake and the game in front for the whole run. A run where either can't be read should count for nothing (void, or a distinct `unproven` state), not pass.

8. **The Neo's status is inconsistent across files.** The harness addendum says the remote loop is not built and WAITING carries only the standing proxy line. NOTES says "Nick asked for remote testing on the Neo", and on that basis the loop, `docs/targets/` and the `remote-test` record exist. WAITING now carries both the "Neo out of the loop (standing)" line and a "Neo one-time setup" line, and `ARCHITECTURE.md` line 179 still says the Neo is out of the loop. Record Nick's instruction word for word with its date (as was done for the AAA goal), then make WAITING and ARCHITECTURE agree with it.

9. **neo-proxy record.**
   - (a) It says benchmarks run with vsync off. They can't on Honeykrisp: `verification-rendering` and every log say vsync is `enabled`.
   - (b) The record's own source puts the M1 Pro's memory bandwidth at about 3.3× the Neo's (200 vs 60 GB/s), but the GPU factor is 2.5. A bandwidth-bound frame could be judged more leniently than on the Neo, which the brief forbids. Give the reason the factor still covers that case, or how bandwidth-bound frames are caught.

10. **Minor.**
    - The `asset-pipeline` record names `tools/build.py`, which doesn't exist; the build step is `tools/verify.py build`.
    - `SETUP.md` omits the generator's Python dependencies (`tools/requirements.txt`, `.local/venv`: tifffile, imagecodecs) and ssh/rsync/niri/Umbriel. `setup-check` doesn't test numpy, and step 1 of "Test machines" points to a "setup brief" that isn't in the repository.
    - `README.md` doesn't mention the `remote` command.
    - Proof evidence comes from dirty trees (`memory.json` at `639dffa…-dirty`, `window.json` at `d00885b…-dirty`).

11. **Minor (build hygiene).** Every export packs about 300 MB of 4K Poly Haven textures that only `look_slice` uses, and `look_slice` is excluded from exports. They are licensed and listed, so this is not a licence problem, only size.

## Notes for other modules (not counted against verify)

- `core`: the empty-scene wall-clock budget sits on its edge. In the critic's normal-launch run of `critic-verify-empty-still-low`, p99 was 22.45 ms (over 22) and the budget failed; four other empty-scene runs passed. Under the `neo` profile the stress scene runs at GPU p50 18.8 ms, wall p95 ~40 ms. The `core-profile-neo-stress-still` still has the menu placeholder's "Ridgeline" label drawn over the 3D picture.
- Privacy, Nick's call: `docs/targets/neo.json` holds the Neo's Tailscale machine name, which includes a first name, and `SETUP.md` holds the tailnet ID. Both go to GitHub with the next push.

## Presets and fixtures the critic added

- `docs/presets/critic-verify-empty-still-low.json`
- `docs/fixtures/critic-verify-frametime-limiter-20.json`, `critic-verify-memory-texture-2048.json`, `critic-verify-memory-texture-2048-6cycles.json`, `critic-verify-sound-tone-minus12.json`, `critic-verify-window-shapes.json`, `critic-verify-missing-scene.json`, `critic-buildcheck/`
- `game/verify/fixtures/critic_texture_2048.{gd,tscn}` (fixture scene only)

No preset is retired this round.

To make the critic's numbers again: the driver scripts used were ad hoc (they call `tools/verify.py`'s `run_preset`, the `PROOFS` table, `export_one` and `check_pack`). Every result is in `docs/evidence/verify/critic-round-1/critic-results.json`, with the log beside each run.
