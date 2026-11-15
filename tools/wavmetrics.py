"""Read the 32-bit float (or 16-bit PCM) WAV the game writes and measure it."""
from __future__ import annotations

import struct

import numpy as np


def read_wav(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("not a WAV file")
    pos = 12
    fmt = None
    samples = None
    while pos + 8 <= len(data):
        cid = data[pos:pos + 4]
        size = struct.unpack("<I", data[pos + 4:pos + 8])[0]
        body = data[pos + 8:pos + 8 + size]
        if cid == b"fmt ":
            fmt = struct.unpack("<HHIIHH", body[:16])
        elif cid == b"data":
            samples = body
        pos += 8 + size + (size & 1)
    if fmt is None or samples is None:
        raise ValueError("missing fmt or data chunk")
    tag, ch, rate, _, _, bits = fmt
    if tag == 3 and bits == 32:
        arr = np.frombuffer(samples, dtype="<f4").astype(np.float64)
    elif tag == 1 and bits == 16:
        arr = np.frombuffer(samples, dtype="<i2").astype(np.float64) / 32768.0
    else:
        raise ValueError(f"unsupported WAV format tag={tag} bits={bits}")
    return arr.reshape(-1, ch), rate


def db(x: float) -> float:
    return float(20 * np.log10(x)) if x > 0 else float("-inf")


def measure(path) -> dict:
    s, rate = read_wav(path)
    peak = float(np.max(np.abs(s))) if s.size else 0.0
    rms = float(np.sqrt(np.mean(s ** 2))) if s.size else 0.0
    return {"rate": rate, "frames": int(s.shape[0]), "seconds": s.shape[0] / rate,
            "peak_dbfs": db(peak), "rms_dbfs": db(rms),
            "clipped_samples": int(np.sum(np.abs(s) >= 1.0))}
