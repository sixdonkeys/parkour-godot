"""Image numbers for the verification tool.

- SSIM (Wang et al. 2004): Gaussian window 11 px, sigma 1.5, K1=0.01, K2=0.03,
  on luminance (Rec. 709 weights), 8-bit dynamic range.
- Histogram distance: total-variation distance (half the L1 distance) between
  normalised histograms; luminance with 64 bins and joint RGB with 8x8x8 bins.
  0 = identical distributions, 1 = disjoint.
"""
from __future__ import annotations

import numpy as np
from PIL import Image

C1 = (0.01 * 255) ** 2
C2 = (0.03 * 255) ** 2


def load_rgb(path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)


def luminance(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def _gauss_kernel(size=11, sigma=1.5) -> np.ndarray:
    x = np.arange(size) - size // 2
    k = np.exp(-(x ** 2) / (2 * sigma ** 2))
    return k / k.sum()


def _filter(img: np.ndarray, k: np.ndarray) -> np.ndarray:
    """Separable 'valid' filter: sums shifted copies, no scipy needed."""
    n = len(k)
    h, w = img.shape
    tmp = np.zeros((h, w - n + 1))
    for i, kv in enumerate(k):
        tmp += kv * img[:, i:i + w - n + 1]
    out = np.zeros((h - n + 1, w - n + 1))
    for i, kv in enumerate(k):
        out += kv * tmp[i:i + h - n + 1, :]
    return out


def ssim(a: np.ndarray, b: np.ndarray) -> float:
    """a, b: RGB float arrays of the same shape."""
    if a.shape != b.shape:
        raise ValueError(f"shape mismatch {a.shape} vs {b.shape}")
    x, y = luminance(a), luminance(b)
    k = _gauss_kernel()
    mx, my = _filter(x, k), _filter(y, k)
    sxx = _filter(x * x, k) - mx * mx
    syy = _filter(y * y, k) - my * my
    sxy = _filter(x * y, k) - mx * my
    num = (2 * mx * my + C1) * (2 * sxy + C2)
    den = (mx * mx + my * my + C1) * (sxx + syy + C2)
    return float(np.mean(num / den))


def hist_luma(rgb: np.ndarray, bins=64) -> np.ndarray:
    h, _ = np.histogram(luminance(rgb), bins=bins, range=(0, 256))
    return h / h.sum()


def hist_rgb(rgb: np.ndarray, bins=8) -> np.ndarray:
    q = np.clip((rgb // (256 // bins)).astype(np.int64), 0, bins - 1)
    idx = q[..., 0] * bins * bins + q[..., 1] * bins + q[..., 2]
    h = np.bincount(idx.ravel(), minlength=bins ** 3).astype(np.float64)
    return h / h.sum()


def tv(p: np.ndarray, q: np.ndarray) -> float:
    return float(0.5 * np.abs(p - q).sum())


def hist_distance(a: np.ndarray, b: np.ndarray) -> dict:
    return {"luma_tv": tv(hist_luma(a), hist_luma(b)), "rgb_tv": tv(hist_rgb(a), hist_rgb(b))}


def fit_same_frame(a: np.ndarray, b: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Scale both to the same height, then crop both to the same centred frame."""
    h = min(a.shape[0], b.shape[0], 1080)

    def scale(img):
        im = Image.fromarray(img.astype(np.uint8))
        w = round(im.width * h / im.height)
        return np.asarray(im.resize((w, h), Image.LANCZOS), dtype=np.float64)

    a2, b2 = scale(a), scale(b)
    w = min(a2.shape[1], b2.shape[1])

    def crop(img):
        x0 = (img.shape[1] - w) // 2
        return img[:, x0:x0 + w]

    return crop(a2), crop(b2)
