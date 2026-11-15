"""Known-answer proofs for the instruments that arrive with `movement`
(input to motion, fuzz, the jump). Called through `tools/verify.py prove`;
each writes under docs/evidence/movement/round-<n>/proofs/.
"""
from __future__ import annotations

import statistics
from pathlib import Path


def _rel(v, p: Path) -> str:
    return str(p.relative_to(v.ROOT))


def prove_input_motion(v, rnd: int) -> dict:
    """A fixed synthetic delay. A block moves 100 ms (then 40 ms) after the
    engine delivers the key press, by the wall clock, and is drawn by the end
    of the frame after that. So a reading from `_input` is the delay plus
    between zero and two frames:
    - no reading is under the delay;
    - no reading is over the delay plus two of the longest frame in the run;
    - the median is the delay plus between half a frame and two frames;
    - the two medians differ by 60 ms, within one frame."""
    cases = []
    ok = True
    medians = {}
    frame = None
    for delay in (100.0, 40.0):
        p = v.FIX / f"movement-latency-delay-{int(delay)}.json"
        out = v.evidence_dir("movement", rnd, "proofs", p.stem)
        log = v.run_preset(p, out, test_mode=False)
        itm = log.get("input_to_motion", {})
        series = itm.get("input_to_first_motion_ms", {}).get("series_ms", [])
        fm = itm.get("frame_ms", {})
        frame = fm.get("p50") or frame
        frame_max = fm.get("max") or 0.0
        lo, hi = delay, delay + 2.0 * frame_max + 1.0
        inside = [lo - 0.05 <= s <= hi for s in series]
        med = statistics.median(series) if series else None
        medians[delay] = med
        med_range = [delay + 0.5 * (frame or 0.0), delay + 2.0 * (frame or 0.0)]
        c_ok = (len(series) >= 50 and all(inside) and itm.get("failed_trials") == 0
                and med is not None and med_range[0] <= med <= med_range[1]
                and log["orchestrator"]["error_count"] == 0 and not log.get("test_mode", True))
        cases.append({"fixture": _rel(v, p), "synthetic_delay_ms": delay, "trials": len(series),
                      "allowed_ms": [lo, round(hi, 2)], "measured_min_ms": min(series) if series else None,
                      "measured_median_ms": med, "allowed_median_ms": [round(x, 2) for x in med_range],
                      "measured_max_ms": max(series) if series else None,
                      "outside": inside.count(False), "frame_ms": fm, "inject_to_input_ms": itm.get("inject_to_input_ms"),
                      "errors": log["orchestrator"]["error_count"], "pass": bool(c_ok),
                      "log": _rel(v, out / "log.json")})
        ok = ok and c_ok
    diff = None
    if medians.get(100.0) is not None and medians.get(40.0) is not None and frame:
        diff = medians[100.0] - medians[40.0]
        ok = ok and abs(diff - 60.0) <= frame
    return {"instrument": "input to motion", "known_answer": "a body that moves a fixed 100 ms / 40 ms after _input",
            "cases": cases, "median_difference_ms": diff, "expected_difference_ms": 60.0,
            "difference_tolerance_ms": frame, "pass": bool(ok)}


def prove_fuzz(v, rnd: int) -> dict:
    """A floor with a deliberate hole and nothing under it: the instrument
    must report a fall through the world. The same floor without the hole:
    it must report none."""
    res = {"instrument": "fuzz", "cases": []}
    ok = True
    for name, want_fall in (("movement-fuzz-hole", True), ("movement-fuzz-solid", False)):
        p = v.FIX / f"{name}.json"
        out = v.evidence_dir("movement", rnd, "proofs", name)
        log = v.run_preset(p, out)
        f = log.get("fixture_result", {}).get("fuzz", {})
        falls = f.get("falls_through_world")
        c_ok = (falls is not None and (falls >= 1) == want_fall and f.get("stuck_states") == 0
                and f.get("non_finite") == 0 and log["orchestrator"]["error_count"] == 0
                and f.get("seconds", 0) >= 59.0)
        res["cases"].append({"fixture": _rel(v, p), "expect_fall_through_world": want_fall,
                             "falls_through_world": falls, "below_kill_plane": f.get("below_kill_plane"),
                             "embedded_in_static": f.get("embedded_in_static"), "stuck_states": f.get("stuck_states"),
                             "non_finite": f.get("non_finite"), "seconds": f.get("seconds"),
                             "first_events": f.get("events", [])[:3], "errors": log["orchestrator"]["error_count"],
                             "pass": bool(c_ok), "log": _rel(v, out / "log.json")})
        ok = ok and c_ok
    res["pass"] = bool(ok)
    return res


def prove_jump(v, rnd: int) -> dict:
    """A body launched at known speeds under a known gravity (10 m/s^2):
    apex, air time and distance must match arithmetic. Then the same answers
    asked of a body under 12 m/s^2: the instrument must say they don't match."""
    res = {"instrument": "movement numbers: jump", "cases": []}
    ok = True
    for name, want_pass in (("movement-jump-known-launch", True), ("movement-jump-wrong-gravity", False)):
        p = v.FIX / f"{name}.json"
        out = v.evidence_dir("movement", rnd, "proofs", name)
        log = v.run_preset(p, out)
        m = log.get("fixture_result", {}).get("metrics", {})
        got = m.get("pass")
        c_ok = got is want_pass and len(m.get("cases", [])) >= 3 and log["orchestrator"]["error_count"] == 0
        res["cases"].append({"fixture": _rel(v, p), "expect_instrument_pass": want_pass, "instrument_pass": got,
                             "gravity_m_s2": m.get("gravity_m_s2"), "launches": m.get("cases"),
                             "errors": log["orchestrator"]["error_count"], "pass": bool(c_ok),
                             "log": _rel(v, out / "log.json")})
        ok = ok and c_ok
    res["pass"] = bool(ok)
    return res


PROOFS = {"input-motion": prove_input_motion, "fuzz": prove_fuzz, "jump": prove_jump}
