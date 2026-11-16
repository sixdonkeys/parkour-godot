# Handoff — Ridgeline (parkour-godot)

Written 2026-11-15 (late evening) by the main builder session on the Fedora laptop (`macbook-m1-pro`). A fresh session reads, in order: `BUILD-BRIEF.md` (the contract), this file, `docs/STATUS.json`, `docs/NOTES.md`, `docs/WAITING.md`.

## Where are we?

Stage 1, day 1.
- **verify:** built. Critic round 1 failed the gate; most fixes are done and round 2 is not yet run.
- **core:** about 80% built.
- **look-slice** (the desert probe): speed brought to about the Neo's budget on branch `fable/desert-budget`, not yet merged; the look itself is far from photographic.
- **movement:** round 1 built and self-checked by a Fable agent, merged into `main` (`15e403e`).
- **The Neo is live:** reached through the remote loop. Three valid Neo runs; calibration says the Neo is about 2.2–2.7× slower than this laptop's GPU.
- Nothing playable yet.

## Done — don't redo

- Remote loop to the Neo, proved (`python3 tools/verify.py remote neo check|bench|play|fetch`).
- Reference set: 71 photos, approved by Nick (`reference/APPROVED.md`). The folder is closed.
- Privacy scrub: the Neo's machine name and the tailnet ID were removed from every commit before the first push (backup ref `refs/original/refs/heads/main` is still local; Nick deletes it).
- Export-profile bug (binary .tres lost values): fixed by shipping text resources.
- Memory-instrument definition settled by Nick (warm cycle).

## Authorized / not authorized

- **Nick decided 2026-11-15:**
  - the memory check measures from after one earlier load and unload of the same level;
  - remove names from the repo, history included (done);
  - ship several quality profiles with an in-game picker, and make every Neo cut a profile setting, never removed detail;
  - hand the hardest jobs to parallel Fable agents (a departure from the brief's "one agent builds");
  - American spelling in all new text.
- **Not yet authorized:**
  - starting brief #7 (replay) — Nick said "wrap up for the night before starting 7";
  - any change to the stage plan, such as a vertical slice (see "What's next").
- Usage: Nick is on a Max plan; warn him before any large agent fan-out.

## What's next, in order (who decides)

1. **Nick:** decide whether to change the plan to reach "playable" sooner. He asked, in his words: "what if we only build the first scene and get it good?" The builder's options are in `docs/NOTES.md` (2026-11-15, last entry).
2. **Builder:** review and merge `fable/desert-budget`. Its last commits are `b00edf6` and `354c469`. The agent was stopped before its final report; its Neo stills in the worktree are untracked on purpose.
3. **Builder:** run the verify critic round 2, then core.
4. **Nick:** go or no-go on brief #7 (replay) as a Fable agent (`docs/briefs/fable-briefs.md` §7), then camera and traversal.

## Pending on Nick

- The plan decision (item 1 above).
- Push: 26+ commits on `main`, not pushed.
- Delete when satisfied: the backup ref above, and the two agent worktrees once their branches are merged.

## Where everything is

- Fable briefs: `docs/briefs/fable-briefs.md`. Look-slice findings: `docs/briefs/look-slice-progress-2026-11-15.md`.
- Agent worktrees (git-ignored): `.claude/worktrees/agent-acc4588acba933c93` (branch `fable/desert-budget`, unmerged), `.claude/worktrees/agent-a2375daaea45fb462` (branch `fable/player-body`, merged).
- Neo: `docs/targets/neo.json`; results in `docs/neo/<date>-<commit>/` with `HONESTY.json` and `CALIBRATION.md`. The Neo needs to be plugged in, with Low Power Mode off, Do Not Disturb on, Amphetamine running, and nobody touching it for 5 minutes before a run starts.
- Git-ignored inputs on this laptop only: `.local/` (export templates, venv, the Neo setup brief), `tools/cache/usgs/`, `game/assets/polyhaven/` (remade with `python3 tools/fetch_assets.py`).
- Long runs: the laptop sleeps when idle. Hold `systemd-inhibit` during agent work (it was released at close-out).
